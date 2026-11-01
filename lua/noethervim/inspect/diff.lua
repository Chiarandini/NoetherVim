--- :NoetherVim diff: a distro file beside the file of yours that changes
--- it, and the dispatcher for the keymaps, options and autocmds
--- comparisons.
---@diagnostic disable: undefined-doc-name

local Snacks = require("snacks")
local ui = require("noethervim.inspect.ui")
local effective_root = ui.effective_root
local HOOKS = ui.HOOKS
local map_to_user_path = ui.map_to_user_path

local M = {}

-- ── Comparison: File side-by-side ───────────────────

--- Scan a directory for .lua module names (without extension).
local function scan_lua_modules(dir)
  local modules = {}
  local handle = vim.uv.fs_scandir(dir)
  if not handle then return modules end
  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if (ftype == "file" or ftype == "link") and name:match("%.lua$") then
      modules[#modules + 1] = name:gsub("%.lua$", "")
    end
  end
  table.sort(modules)
  return modules
end

--- Open upstream and the user override side by side, in diff mode.
---
--- `diffthis` on both windows is the point of the command: without it this
--- is two files next to each other and the reader does the comparing, which
--- is exactly the work `:NoetherVim diff` exists to save. Falls back to a
--- lone upstream window when there is no override to compare against.
---
--- Upstream opens readonly outside dev mode, matching every other picker
--- that surfaces distribution source.
---@param upstream string
---@param user_file string?
local function open_pair(upstream, user_file)
  if vim.g.noethervim_dev then
    vim.cmd("edit " .. vim.fn.fnameescape(upstream))
  else
    vim.cmd("view " .. vim.fn.fnameescape(upstream))
    vim.bo.readonly = true
    vim.bo.modifiable = false
  end
  if not user_file then return end

  vim.cmd("diffthis")
  vim.cmd("vsplit " .. vim.fn.fnameescape(user_file))
  vim.cmd("diffthis")
end

--- Open a side-by-side diff for a specific module (direct call path).
--- Used by :NoetherVim diff <name> when a name is provided.
local function open_diff_split(module_name)
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end

  local upstream = nil
  local candidates = {
    HOOKS[module_name] and (root .. "/" .. HOOKS[module_name]) or "",
    root .. "/lua/noethervim/" .. module_name .. ".lua",
    root .. "/after/lsp/" .. module_name .. ".lua",
  }
  for _, path in ipairs(candidates) do
    if vim.uv.fs_stat(path) then
      upstream = path
      break
    end
  end
  -- Core units and bundles live under category subdirectories; search by
  -- basename.
  for _, dir in ipairs({ "core", "bundles" }) do
    for _, entry in ipairs(require("noethervim.util").scan_bundles(root .. "/lua/noethervim/" .. dir)) do
      if not upstream and entry.name == module_name then upstream = entry.path end
    end
  end

  if not upstream then
    return vim.notify("NoetherVim: no upstream file found for '" .. module_name .. "'", vim.log.levels.WARN)
  end

  local target = map_to_user_path(upstream)
  local user_file = target and vim.uv.fs_stat(target) and target or nil

  open_pair(upstream, user_file)
  if not user_file then
    vim.notify("NoetherVim: no user override for '" .. module_name .. "' (showing upstream only)", vim.log.levels.INFO)
  end
end

--- Open a side-by-side diff of a NoetherVim core module against the user's
--- override for the same module. With no argument, presents a Snacks picker
--- of every module that has (or could have) an override.
---
---@param module_name? string  Bare module name (e.g. "telescope", "snacks").
function M.diff_file(module_name)
  -- Direct open when called with a specific module name
  if module_name and module_name ~= "" then
    open_diff_split(module_name)
    return
  end

  -- Picker mode -- browse all diffable modules
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end
  local icons = require("noethervim.util.icons")

  local diff_cat_order = { Core = 1, Plugin = 2, Bundle = 3, LSP = 4 }
  -- Flat-scan groups (the hook files, core units and bundles are handled
  -- separately).
  local groups = {
    { cat = "LSP",    dir = root .. "/after/lsp" },
  }

  -- Detect which bundles are enabled (same logic as the bundles picker).
  local enabled_bundles = {}
  local ok, lazy_cfg = pcall(require, "lazy.core.config")
  if ok and lazy_cfg.spec then
    for _, mod in ipairs(lazy_cfg.spec.modules) do
      local tail = mod:match("^noethervim%.bundles%.(.+)$")
      if tail then
        local name = tail:match("([^.]+)$")
        enabled_bundles[name] = true
      end
    end
  end

  local items = {}

  -- Only files a file of yours can change are listed.
  local function add_item(cat, name, upstream_path, is_enabled)
    local target = map_to_user_path(upstream_path)
    if not target then return end
    local user_path = vim.uv.fs_stat(target) and target or nil
    table.insert(items, {
      text      = cat .. " " .. name
                  .. (is_enabled and " enabled" or "")
                  .. (user_path and " override" or ""),
      file      = upstream_path,
      cat       = cat,
      cat_order = diff_cat_order[cat] or 99,
      name      = name,
      upstream  = upstream_path,
      user_file = user_path,
      has_override = user_path ~= nil,
      enabled   = is_enabled,
    })
  end

  for name, rel in pairs(HOOKS) do add_item("Core", name, root .. "/" .. rel, true) end
  for _, group in ipairs(groups) do
    for _, mod in ipairs(scan_lua_modules(group.dir)) do
      add_item(group.cat, mod, vim.fs.joinpath(group.dir, mod .. ".lua"), true)
    end
  end

  for _, entry in ipairs(require("noethervim.util").scan_bundles(root .. "/lua/noethervim/core")) do
    add_item("Plugin", entry.name, entry.path, true)
  end
  for _, entry in ipairs(require("noethervim.util").scan_bundles(root .. "/lua/noethervim/bundles")) do
    add_item("Bundle", entry.name, entry.path, enabled_bundles[entry.name] or false)
  end

  table.sort(items, function(a, b)
    if a.cat_order ~= b.cat_order then return a.cat_order < b.cat_order end
    return a.name < b.name
  end)

  Snacks.picker({
    title   = "NoetherVim Module Comparison",
    items   = items,
    preview = "file",
    format  = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-10s", "[" .. item.cat .. "]"), "SnacksPickerLabel" }
      ret[#ret + 1] = { string.format(" %-22s", item.name) }
      -- Enabled status (checkmark for enabled bundles, spacer otherwise)
      if item.cat == "Bundle" and item.enabled then
        ret[#ret + 1] = { icons.checkmark .. " ", "DiagnosticOk" }
      else
        ret[#ret + 1] = { "  " }
      end
      -- Override status
      if item.has_override then
        ret[#ret + 1] = { "override", "DiagnosticWarn" }
      else
        ret[#ret + 1] = { "--", "Comment" }
      end
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      open_pair(item.upstream, item.user_file)
      if not item.user_file then
        vim.notify("NoetherVim: no user override for '" .. item.name .. "' (showing upstream only)", vim.log.levels.INFO)
      end
    end,
  })
end

-- ── Diff dispatcher ──────────────────────────────────────────────

--- Semantic diff targets: these compare live state, not file contents.
local SEMANTIC_DIFF_TARGETS = { "keymaps", "options", "autocmds" }

--- Subcommand dispatcher for `:NoetherVim diff`.
---
---@param what? "keymaps"|"options"|"autocmds"|string
---     The three semantic targets open their own comparison picker; any
---     other string is treated as a module name and forwarded to
---     `diff_file()`, which falls back to a module picker when nil.
function M.diff(what)
  if what == "keymaps" then
    require("noethervim.inspect.diff_keymaps").diff_keymaps()
  elseif what == "options" then
    require("noethervim.inspect.diff_options").diff_options()
  elseif what == "autocmds" then
    require("noethervim.inspect.diff_autocmds").diff_autocmds()
  else
    M.diff_file(what)
  end
end

--- Every accepted argument to `:NoetherVim diff` -- the semantic targets
--- first, then one entry per distro module (core, plugin, lsp, bundle).
---@return string[]
local function diff_targets()
  local targets, seen = {}, {}
  for _, name in ipairs(SEMANTIC_DIFF_TARGETS) do
    seen[name] = true
    targets[#targets + 1] = name
  end
  local root = effective_root()
  if not root then return targets end

  local modules = {}
  for name in pairs(HOOKS) do
    if not seen[name] then
      seen[name] = true
      modules[#modules + 1] = name
    end
  end
  for _, dir in ipairs({
    root .. "/lua/noethervim",
    root .. "/after/lsp",
  }) do
    for _, mod in ipairs(scan_lua_modules(dir)) do
      if mod ~= "init" and not seen[mod] then
        seen[mod] = true
        modules[#modules + 1] = mod
      end
    end
  end
  local util = require("noethervim.util")
  for _, dir in ipairs({ "core", "bundles" }) do
    for _, entry in ipairs(util.scan_bundles(root .. "/lua/noethervim/" .. dir)) do
      if not seen[entry.name] then
        seen[entry.name] = true
        modules[#modules + 1] = entry.name
      end
    end
  end
  table.sort(modules)
  vim.list_extend(targets, modules)
  return targets
end
M.targets = diff_targets

return M
