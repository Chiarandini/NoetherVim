-- NoetherVim ftplugin: lua
-- StyLua defaults to 120; align comment auto-wrap and `gq` reflow with that.
-- Runtime ftplugin/lua.vim handles formatoptions and commentstring.

vim.bo.textwidth = 120

-- <C-]> on a module name in a string opens the module (noethervim.lua_tags).
vim.bo.tagfunc = "v:lua.require'noethervim.lua_tags'.tagfunc"
