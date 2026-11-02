--- 'tagfunc' for Lua buffers: <C-]>, <C-w>] and :tag on a module name in a
--- string (`import = "noethervim.bundles.languages.latex"`,
--- `require("noethervim.pick")`) open that module's file, the way gf does,
--- and push the tag stack so <C-t> comes back. Anything else falls through
--- to the language server's tagfunc, then to regular tags.

local M = {}

--- The file of the Lua module `name` on the runtimepath, if there is one.
---@param name string
---@return string?
local function module_file(name)
  if not name:match("^[%w_][%w_.-]*$") then return nil end
  local path = name:gsub("%.", "/")
  return vim.api.nvim_get_runtime_file("lua/" .. path .. ".lua", false)[1]
    or vim.api.nvim_get_runtime_file("lua/" .. path .. "/init.lua", false)[1]
end

function M.tagfunc(pattern, flags, _info)
  -- 'c': invoked from normal mode, so the cursor is there to read. The
  -- pattern is the keyword under it, which stops at the first dot.
  if flags:find("c") then
    local file = module_file(vim.fn.expand("<cfile>"))
    if file then return { { name = pattern, filename = file, cmd = "1" } } end
  end
  local ok, matches = pcall(vim.lsp.tagfunc, pattern, flags)
  if ok and type(matches) == "table" and #matches > 0 then return matches end
  return vim.NIL
end

return M
