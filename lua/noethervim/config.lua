--- The one place NoetherVim reads your configuration.
---
--- `get()` returns the table `lua/user/config.lua` returns, read once, or an
--- empty table when the file is missing or the user layer is off. The layer
--- is off under `NOETHERVIM_NO_USER=1` or `vim.g.noethervim_no_user`: then
--- nothing of yours is read, and `user_dir()` is nil, so your snippets,
--- preamble templates and spellfile stay out of the session too.

local M = {}

--- True when the user layer is switched off for this session.
---@return boolean
function M.user_off()
  return (vim.env.NOETHERVIM_NO_USER or vim.g.noethervim_no_user) and true or false
end

--- Your config directory, or nil when the user layer is off.
---@return string?
function M.user_dir()
  if M.user_off() then return nil end
  return vim.fn.stdpath("config")
end

--- True when `lsp = { [name] = false }` in lua/user/config.lua drops
--- NoetherVim's settings for server `name` (after/lsp/<name>.lua).
---@param name string
---@return boolean
function M.lsp_off(name)
  local lsp = M.get().lsp
  return type(lsp) == "table" and lsp[name] == false
end

local cache ---@type noethervim.UserConfig?

--- `lua/user/config.lua`, or `{}`.
---@return noethervim.UserConfig
function M.get()
  if cache then return cache end
  cache = {}
  if M.user_off() then return cache end
  local ok, loaded = pcall(require, "user.config")
  if ok and type(loaded) == "table" then
    cache = loaded
  elseif ok and loaded ~= nil then
    vim.notify("lua/user/config.lua: expected a table, got " .. type(loaded), vim.log.levels.WARN)
  elseif not ok and not tostring(loaded):find("module 'user.config' not found", 1, true) then
    vim.notify("lua/user/config.lua: " .. tostring(loaded), vim.log.levels.WARN)
  end
  return cache
end

--- What is wrong in `lua/user/config.lua`: type errors, one message per
--- bad field, and the keys nothing reads (dotted when nested).
---@return string[] errors, string[] unknowns
function M.validate()
  return require("noethervim.util.config").validate_user_config(M.get())
end

--- Take the config directory and its after/ off 'runtimepath', so Neovim
--- sources none of your plugin/, after/, ftplugin/ or colors/ files.
--- Runs while lazy.nvim reads specs, after its 'runtimepath' reset.
function M.prune_rtp()
  local function real(p) return vim.fs.normalize(vim.uv.fs_realpath(p) or p) end
  local cfg = real(vim.fn.stdpath("config"))
  local kept = {}
  for _, path in ipairs(vim.opt.rtp:get()) do
    local r = real(path)
    if r ~= cfg and r ~= cfg .. "/after" then table.insert(kept, path) end
  end
  vim.opt.rtp = kept
end

return M
