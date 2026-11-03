--- NoetherVim utility module
--- Usage:  local nv = require("noethervim.util")
---         nv.icons.search  →  "󰍉"

local M = {}

M.icons         = require("noethervim.util.icons")
M.search_leader = vim.g.mapsearchleader or "<space>"

--- The `opts` for a unit's which-key fragment: appends `spec` (which-key's
--- own spec entries: group labels, icons) to what other units added, so a
--- label goes when its unit does.
---
---   specs = { { "which-key.nvim", optional = true,
---     opts = require("noethervim.util").labels({ { "<leader>d", group = "Debug" } }) } }
---
--- A function for the reason rows.contribute is one: lazy.nvim's
--- `opts_extend` reaches only the fragments merged after the one declaring it.
---@param spec table[]
---@return fun(plugin: table, opts: table): table
function M.labels(spec)
  return function(_, opts)
    opts.spec = opts.spec or {}
    table.insert(opts.spec, { mode = { "n", "v" }, spec })
    return opts
  end
end

--- A plugin's merged `opts` (every spec's, yours included), resolved when it
--- is called: the value for the `g` section of a plugin that has no setup()
--- and reads its settings from a global accepting a function
--- (rustaceanvim, neominimap), so `opts` on that plugin's spec reaches it as
--- on any other.
---
---   specs = { { "NoetherVim", optional = true, opts = { g = {
---     rustaceanvim = require("noethervim.util").opts_of("rustaceanvim") } } } }
---@param plugin string lazy.nvim name of the plugin
---@return fun(): table
function M.opts_of(plugin)
  return function()
    local p = require("lazy.core.config").plugins[plugin]
    return p and require("lazy.core.plugin").values(p, "opts", false) or {}
  end
end

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
--- The key that opens init.lua, read from the live keymap table rather than
--- hardcoded, so a rebind is reflected and an unmapped one is noticed.
---
--- More than one key can open it -- the distribution binds `<leader>i`, and
--- a user config may bind its own -- and `nvim_get_keymap` has no meaningful
--- order, so take the shortest. That is both deterministic and the one worth
--- telling someone about. Returned in press-it form (`\i`, `<Space>ev`).
--- nil when nothing opens init.lua any more.
local function init_lua_key()
  local best
  for _, km in ipairs(vim.api.nvim_get_keymap("n")) do
    if (km.rhs or ""):find("MYVIMRC", 1, true) then
      if not best or #km.lhs < #best or (#km.lhs == #best and km.lhs < best) then
        best = km.lhs
      end
    end
  end
  return best and vim.fn.keytrans(
    vim.api.nvim_replace_termcodes(best, true, true, true))
end

--- Footer for a notification that will not time out. A toast that stays
--- until dismissed has to say how to dismiss it, or it reads as a hang.
--- Spec errors additionally get the key that opens the file to fix, since
--- that is the whole of the remedy.
local function persistent_hint(msg)
  local parts = {}
  if msg:find("specs found for module", 1, true) then
    local key = init_lua_key()
    parts[#parts + 1] = key and (key .. "  open init.lua")
      or ("edit " .. vim.fn.fnamemodify(vim.env.MYVIMRC or "", ":~"))
  end
  parts[#parts + 1] = "<Esc>  dismiss"
  return table.concat(parts, "     ")
end

--- Errors in the queue are replayed without a timeout, so they stay on
--- screen until dismissed. Everything replayed here happened before the
--- session was usable and cannot be scrolled back to; a stale bundle import
--- that flashes for three seconds while plugins are still settling is a
--- message nobody reads. Warnings and below keep the notifier's own timeout.
--- Only the timeout is set, so a caller that asked for something specific
--- keeps it.
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
          local msg, level, opts = n[1], n[2], n[3]
          if level == vim.log.levels.ERROR then
            opts = vim.tbl_extend("keep", opts or {}, { timeout = 0 })
            msg = msg .. "\n\n" .. persistent_hint(msg)
          end
          vim.notify(msg, level, opts)
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

local warned_state = false

--- Write one of NoetherVim's state files (under stdpath("state")),
--- creating its directory. A file that cannot be written, left owned by
--- root by `sudo nvim` say, is reported once a session, with the fix,
--- instead of raising: the change it records still holds until Neovim quits.
---@param path string
---@param lines string[]
---@return boolean written
function M.write_state(path, lines)
  local ok, res = pcall(function()
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    return vim.fn.writefile(lines, path)
  end)
  if ok and res == 0 then return true end
  if not warned_state then
    warned_state = true
    local state = vim.fn.fnamemodify(vim.fn.stdpath("state"), ":~")
    vim.notify(("NoetherVim cannot write %s, so this change lasts until Neovim quits. "
      .. "If `sudo nvim` left files there owned by root: sudo chown -R $USER %s")
      :format(vim.fn.fnamemodify(path, ":~"), state), vim.log.levels.WARN)
  end
  return false
end

return M
