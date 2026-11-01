--- Helpers the :NoetherVim subcommands share: where NoetherVim and your
--- config live, which file of yours changes a distro file, and the
--- picker pieces (the readonly opener, the key-hint footer).
---@diagnostic disable: undefined-doc-name

local Snacks = require("snacks")

local M = {}

--- Resolve the root directory of the NoetherVim installation.
local function noethervim_root()
  local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
  if not init then return nil end
  -- init is <root>/lua/noethervim/init.lua → go up 3 levels
  return vim.fn.fnamemodify(init, ":h:h:h")
end

--- Return the effective NoetherVim root: the dev directory when
--- vim.g.noethervim_dev is set, otherwise the installed location.
local function effective_root()
  if vim.g.noethervim_dev then
    return vim.fn.expand(vim.g.noethervim_dev)
  end
  return noethervim_root()
end

--- Resolve the user config lua/user/ directory.
local function user_dir()
  return vim.fn.stdpath("config") .. "/lua/user/"
end

--- The hook files (lua/user/<name>.lua) and the distro file each sits on top of.
local HOOKS = {
  options    = "lua/noethervim/options.lua",
  keymaps    = "lua/noethervim/keymaps.lua",
  autocmds   = "lua/noethervim/autocmds.lua",
  highlights = "lua/noethervim/theme/highlights.lua",
}
local HOOK_OF = {}
for name, rel in pairs(HOOKS) do HOOK_OF[rel] = name end

--- The file of yours that changes the NoetherVim file at `rel`, and its
--- category. Both paths are relative: `rel` to the distribution root, the
--- result to your config directory. Nil for a file nothing of yours can
--- stand in for.
---@param rel string
---@return string?, string?
local function counterpart(rel)
  -- lua/noethervim/core/<category>/<name>.lua → user/plugins/<name>.lua
  local unit = rel:match("^lua/noethervim/core/[^/]+/([^/]+%.lua)$")
  if unit then return "lua/user/plugins/" .. unit, "plugin" end
  -- lua/noethervim/lib/<unit>/<file> → user/plugins/<unit>.lua, the unit
  -- that file belongs to
  local lib = rel:match("^lua/noethervim/lib/([^/]+)/")
  if lib then return "lua/user/plugins/" .. lib:gsub("_", "-") .. ".lua", "plugin" end
  -- lua/noethervim/bundles/<category>/<name>.lua → user/plugins/<name>.lua
  -- User overrides target the bundle by its bare name -- the category
  -- subdirectory is purely organizational in the distro.
  local bundle = rel:match("^lua/noethervim/bundles/[^/]+/([^/]+%.lua)$")
  if bundle then return "lua/user/plugins/" .. bundle, "bundle" end
  -- after/lsp/<name>.lua → your after/lsp/<name>.lua, which loads after it
  local lsp = rel:match("^after/lsp/(.+%.lua)$")
  if lsp then return "after/lsp/" .. lsp, "lsp" end
  -- options, keymaps, autocmds, theme/highlights → the hook file
  local hook = HOOK_OF[rel]
  if hook then return "lua/user/" .. hook .. ".lua", hook == "keymaps" and "keys" or "core" end
  if rel == "lua/noethervim/toggles/options.lua" then return "lua/user/keymaps.lua", "keys" end
  -- the profiles → after/ftplugin/<ft>.lua, the native per-filetype place
  if rel == "lua/noethervim/profiles/apply.lua" then return "after/ftplugin/", "profile" end
  -- ftplugin/<path> → after/ftplugin/<path>, which runs after it
  local ft = rel:match("^ftplugin/(.+)$")
  if ft then return "after/ftplugin/" .. ft, "ftplugin" end
end

--- `path` relative to the NoetherVim root, or nil outside it. Symlinks are
--- resolved on both sides, so a root under a linked directory (/tmp on
--- macOS) still matches.
---@param path string
---@return string?
local function relative(path)
  local root = effective_root()
  if not root then return nil end
  path = vim.uv.fs_realpath(path) or vim.fs.normalize(path)
  root = vim.uv.fs_realpath(root) or vim.fs.normalize(root)
  if not vim.startswith(path, root .. "/") then return nil end
  return path:sub(#root + 2)
end

--- Map a NoetherVim source file to the file of yours that changes it.
--- Returns (user_path, category) or (nil, nil) for a file nothing of yours
--- can stand in for.
local function map_to_user_path(bufpath)
  local rel = relative(bufpath)
  if not rel then return nil, nil end
  local target, category = counterpart(rel)
  if not target then return nil, nil end
  return vim.fn.stdpath("config") .. "/" .. target, category
end

--- Get snapshot data from the init module.
local function snapshots()
  return require("noethervim")._snapshots_now()
end

--- Confirm callback for pickers that should open files readonly.
--- Prevents accidental edits to distribution source or installed plugins.
--- In dev mode (vim.g.noethervim_dev), NoetherVim source files open editable.
local function confirm_readonly(picker, item)
  picker:close()
  if not item or not item.file then return end
  -- Resolve the full path (item.file may be relative to item.cwd)
  local file = Snacks.picker.util.path(item)
  if not file then return end
  -- In dev mode, open NoetherVim source files as editable
  local editable = false
  if vim.g.noethervim_dev then
    local dev = vim.fs.normalize(vim.fn.expand(vim.g.noethervim_dev))
    editable = vim.startswith(vim.fs.normalize(file), dev)
  end
  if editable then
    vim.cmd("edit " .. vim.fn.fnameescape(file))
  else
    vim.cmd("view " .. vim.fn.fnameescape(file))
    vim.bo.readonly = true
    vim.bo.modifiable = false
  end
  if item.pos and item.pos[1] and item.pos[1] > 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], item.pos[2] or 0 })
    vim.cmd("norm! zzzv")
  end
end

--- Build a snacks footer listing the picker's non-obvious keys.
---
--- Snacks draws this on the input window's bottom border, which spans the
--- list column only -- roughly 45% of the screen. Neovim truncates a longer
--- footer without warning, so hints are dropped from the front (the most
--- obvious keys) until the assembled text fits, and the full key list stays
--- one `<F1>` away.
---
--- The budget scales with the terminal rather than assuming 80 columns, so a
--- wide window shows every hint instead of silently dropping the ones a
--- narrow window could not have fitted either way.
---@param hints [string, string][]  { key, label } pairs, least important first
---@return snacks.picker.Highlight[]
local function hint_footer(hints)
  local budget = math.max(20, math.floor(vim.o.columns * 0.45))
  local width = 2 -- the leading and trailing pad below
  local kept = {}
  for i = #hints, 1, -1 do
    local cost = #hints[i][1] + 1 + #hints[i][2] + (#kept > 0 and 2 or 0)
    if width + cost > budget then break end
    width = width + cost
    table.insert(kept, 1, hints[i])
  end

  local footer = { { " ", "SnacksFooter" } }
  for i, hint in ipairs(kept) do
    if i > 1 then footer[#footer + 1] = { "  ", "SnacksFooter" } end
    footer[#footer + 1] = { hint[1], "SnacksFooterKey" }
    footer[#footer + 1] = { " " .. hint[2], "SnacksFooterDesc" }
  end
  footer[#footer + 1] = { " ", "SnacksFooter" }
  return footer
end

M.noethervim_root = noethervim_root
M.effective_root = effective_root
M.user_dir = user_dir
M.HOOKS = HOOKS
M.counterpart = counterpart
M.relative = relative
M.map_to_user_path = map_to_user_path
M.snapshots = snapshots
M.confirm_readonly = confirm_readonly
M.hint_footer = hint_footer

return M
