--- NoetherVim utility module
--- Usage:  local nv = require("noethervim.util")
---         nv.icons.search  →  "󰍉"

local M = {}

M.icons         = require("noethervim.util.icons")
M.copy_pdf      = require("noethervim.util.copy_pdf")
M.search_leader = vim.g.mapsearchleader or "<space>"

--- Plain (non-magic) string replacement.
---@param s string
---@param substring string
---@param replacement string
---@param n? integer  max replacements
---@return string
function M.str_replace(s, substring, replacement, n)
  return (s:gsub(substring:gsub("%p", "%%%0"), replacement:gsub("%%", "%%%%"), n))
end

--- Buffer every `vim.notify` call until VimEnter, then replay the queue
--- through whatever notifier is in place by then (typically
--- `snacks.notifier`, which renders toasts asynchronously).
---
--- Call this once, immediately before `require("lazy").setup({...})`, so
--- that notifications lazy emits while resolving the spec -- most
--- importantly the `No specs found for module "..."` error fired for a
--- stale bundle reference in init.lua -- do not land on the cmdline as
--- ErrorMsg, which would otherwise trigger the hit-enter prompt on top
--- of the dashboard. The messages still arrive; they arrive as toasts.
---
--- Non-destructive on restore: snacks.notifier installs itself by
--- reassigning `vim.notify` during its `config()` (which runs during
--- `lazy.setup`, i.e. between `buffer_notify()` and VimEnter). If we
--- unconditionally restored `vim.notify` on VimEnter, we would
--- clobber snacks and every later notification (e.g. :Lazy update
--- toasts) would fall back to Neovim's default cmdline notify. Only
--- restore when our wrapper is still the active `vim.notify`; if
--- someone else has taken over, leave them in place -- our wrapper
--- is already an orphan and the replacement is exactly who we want to
--- replay the queue through.
---
--- Idempotent: repeated calls do nothing after the first.
function M.buffer_notify()
  if M._notify_buffered then return end
  M._notify_buffered = true
  local orig = vim.notify
  local pending = {}
  local wrapper
  wrapper = function(msg, level, opts)
    pending[#pending + 1] = { msg, level, opts }
  end
  vim.notify = wrapper
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      if vim.notify == wrapper then
        vim.notify = orig
      end
      vim.schedule(function()
        for _, n in ipairs(pending) do
          vim.notify(n[1], n[2], n[3])
        end
      end)
    end,
  })
end

--- Enumerate all bundle files under `bundles_dir`.
--- Walks the category-subdirectory layout: bundles/<category>/<name>.lua.
--- Returns a list of { path, name, category } entries, sorted by
--- (category, name).
---@param bundles_dir string  absolute path to lua/noethervim/bundles
---@return { path: string, name: string, category: string }[]
function M.scan_bundles(bundles_dir)
  local result = {}
  local root = vim.uv.fs_scandir(bundles_dir)
  if not root then return result end
  while true do
    local cat_name, cat_type = vim.uv.fs_scandir_next(root)
    if not cat_name then break end
    if cat_type == "directory" then
      local sub = vim.uv.fs_scandir(vim.fs.joinpath(bundles_dir, cat_name))
      if sub then
        while true do
          local fname, ftype = vim.uv.fs_scandir_next(sub)
          if not fname then break end
          if (ftype == "file" or ftype == "link") and fname:match("%.lua$") then
            result[#result + 1] = {
              path     = vim.fs.joinpath(bundles_dir, cat_name, fname),
              name     = fname:gsub("%.lua$", ""),
              category = cat_name,
            }
          end
        end
      end
    end
  end
  table.sort(result, function(a, b)
    if a.category ~= b.category then return a.category < b.category end
    return a.name < b.name
  end)
  return result
end

--- Map resolved keymap lhs values to the spec file that defines them.
--- Combines lazy.nvim's key handler data (key_id -> plugin_name) with a
--- scan of NoetherVim spec files (plugin_name -> file path).
---
--- Both tables are keyed by `<mode>|<resolved_lhs>` (e.g. `"n|<Space>fb"`).
--- Keymaps set directly via vim.keymap.set (not in a lazy spec) are absent
--- from both tables; those are tracked by util.keymap_registry instead.
---
---@return table<string, string> sources
---     Mapping from `<mode>|<resolved_lhs>` to absolute path of the spec
---     file that registered the key.
---@return table<string, true> managed
---     Set of `<mode>|<resolved_lhs>` for ALL lazy handler keys, including
---     dev/user-only plugins without a mapped spec file. Membership without
---     a corresponding `sources` entry means "lazy registered this but we
---     can't attribute it to a file."
function M.keymap_sources()
  local sources, managed = {}, {}

  -- Build plugin_name -> spec file by scanning for repo strings
  local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
  local root = init and vim.fn.fnamemodify(init, ":h:h:h")
  if not root then return sources, managed end

  local plugin_files = {}
  local user_plugins = vim.fn.stdpath("config") .. "/lua/user/plugins"

  -- Collect files: plugins/ (flat), bundles/ (category subdirs), user/plugins/ (flat).
  local files = {}
  for _, dir in ipairs({ root .. "/lua/noethervim/plugins", user_plugins }) do
    local handle = vim.uv.fs_scandir(dir)
    if handle then
      while true do
        local name, ftype = vim.uv.fs_scandir_next(handle)
        if not name then break end
        if (ftype == "file" or ftype == "link") and name:match("%.lua$") then
          files[#files + 1] = vim.fs.joinpath(dir, name)
        end
      end
    end
  end
  for _, entry in ipairs(M.scan_bundles(root .. "/lua/noethervim/bundles")) do
    files[#files + 1] = entry.path
  end

  -- Build the set of plugin names lazy knows about. We scan spec files
  -- for exactly these names (as quoted strings), which handles both the
  -- common `"user/repo"` form and dev specs like `"KeyboardMode.nvim"`
  -- that do not carry a slash.
  local plugin_names = {}
  local ok_cfg_pre, lazy_cfg_pre = pcall(require, "lazy.core.config")
  if ok_cfg_pre and lazy_cfg_pre.plugins then
    for name, _ in pairs(lazy_cfg_pre.plugins) do
      plugin_names[name] = true
    end
  end

  -- `plugin_files_all[name]` holds every spec file that mentions the
  -- plugin, in scan order (distro first, then user plugins, then
  -- bundles). The legacy `plugin_files[name]` keeps only the first hit
  -- for backwards-compat; attribution below consults the full list to
  -- pick the file that actually contains each specific lhs.
  local plugin_files_all = {}
  for _, filepath in ipairs(files) do
    local deps_depth = nil
    local depth = 0
    local seen_in_file = {}
    for _, line in ipairs(vim.fn.readfile(filepath)) do
      if line:find("dependencies") and line:find("{") then
        deps_depth = depth
      end
      for c in line:gmatch("[{}]") do
        depth = depth + (c == "{" and 1 or -1)
      end
      if deps_depth and depth <= deps_depth then
        deps_depth = nil
      end
      if not deps_depth then
        -- Any quoted string on this line that matches a known plugin name.
        for token in line:gmatch('"([^"]+)"') do
          local tail = token:match("([^/]+)$") or token
          local name = plugin_names[token] and token
                    or plugin_names[tail] and tail
          if name then
            if not plugin_files[name] then plugin_files[name] = filepath end
            if not seen_in_file[name] then
              seen_in_file[name] = true
              plugin_files_all[name] = plugin_files_all[name] or {}
              plugin_files_all[name][#plugin_files_all[name] + 1] = filepath
            end
          end
        end
      end
    end
  end

  -- File-content cache for attribution-by-lhs.
  local _content = {}
  local function content_of(path)
    if _content[path] == nil then
      local ok, lines = pcall(vim.fn.readfile, path)
      _content[path] = ok and table.concat(lines, "\n") or ""
    end
    return _content[path]
  end

  local registry = require("noethervim.util.keymap_registry")

  --- Pick the file from `candidates` that actually mentions a source
  --- form of `lhs`; falls back to the first candidate if none match.
  local function pick_file_for_lhs(candidates, lhs)
    if not candidates or #candidates == 0 then return nil end
    if #candidates == 1 then return candidates[1] end
    local forms = registry.source_forms(lhs)
    for _, file in ipairs(candidates) do
      local c = registry.canon(content_of(file))
      for _, f in ipairs(forms) do
        local cf = registry.canon(f)
        if cf ~= ""
           and (c:find('"' .. cf .. '"', 1, true)
                or c:find("'" .. cf .. "'", 1, true)) then
          return file
        end
      end
    end
    return candidates[1]
  end

  -- Iterate over each plugin's own key handlers to get the defining
  -- plugin (not the handler plugin, which managed would give us).
  local ok_cfg, lazy_cfg = pcall(require, "lazy.core.config")
  if ok_cfg and lazy_cfg.plugins then
    for name, plugin in pairs(lazy_cfg.plugins) do
      local candidates = plugin_files_all[name]
      local keys = plugin._ and plugin._.handlers and plugin._.handlers.keys
      if keys then
        for id in pairs(keys) do
          -- Handler ids are resolved terminal codes. Convert back to
          -- the notation nvim_get_keymap uses (keytrans, but with
          -- literal space instead of <Space>).
          local base, mode_suffix = id:match("^(.+) %(([^,)]+)%)$")
          if not base or not mode_suffix or #mode_suffix > 2 then
            base = id
            mode_suffix = "n"
          end
          local lhs = vim.fn.keytrans(base):gsub("<Space>", " ")
          local key = mode_suffix .. "|" .. lhs
          managed[key] = true
          local file = pick_file_for_lhs(candidates, lhs)
          if file then sources[key] = file end
        end
      end
    end
  end

  return sources, managed
end

return M
