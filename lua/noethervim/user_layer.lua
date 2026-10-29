--- The user layer: your `lua/user/{options,keymaps,autocmds,highlights}.lua`.
---
--- Sourced from `after/plugin/noethervim.lua`, so they run once every start
--- plugin has been configured, and before your own `after/plugin/` files.
--- Sourced, not required: each keeps its own script id, so `:verbose set`
--- names your file and NoetherVim's later writes can tell your values from
--- its own. Nothing runs under NOETHERVIM_NO_USER.

local M = {}

M.FILES = { "options", "keymaps", "autocmds", "highlights" }

local paths = {} ---@type table<string, true>
local ran = false

local function real(path)
  return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

function M.run()
  if ran then return end
  ran = true
  local nv = require("noethervim")
  local dir = require("noethervim.config").user_dir()
  if not dir then return end
  for _, name in ipairs(M.FILES) do
    local path = dir .. "/lua/user/" .. name .. ".lua"
    if vim.uv.fs_stat(path) then
      paths[real(path)] = true
      local ok, err = pcall(vim.cmd.source, vim.fn.fnameescape(path))
      if ok then
        table.insert(nv._user_modules, name)
      else
        vim.notify("lua/user/" .. name .. ".lua: " .. tostring(err), vim.log.levels.WARN)
      end
    end
  end
end

--- Whether the script `sid` is one of yours: a hook file above, or any file
--- in your config directory but `init.lua` (whose id NoetherVim's start
--- plugins share while lazy.nvim configures them).
---@param sid integer
---@return boolean
function M.is_yours(sid)
  if not sid or sid <= 0 then return false end
  local info = vim.fn.getscriptinfo({ sid = sid })[1]
  if not info then return false end
  local path = real(info.name)
  if paths[path] then return true end
  local dir = require("noethervim.config").user_dir()
  if not dir then return false end
  local root = real(dir)
  return vim.startswith(path, root .. "/") and path ~= root .. "/init.lua"
end

return M
