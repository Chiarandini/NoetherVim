local map = function(mode, lhs, rhs, opt)
	vim.keymap.set(mode, lhs, rhs, opt)
end

local Opts = function(desc)
	return  {silent = true, buffer = true, desc = desc}
end
vim.opt_local.spell = true

-- NOTE: no longer useful, better keymap now default in Neorg
-- keeping in case I want to do something like this somewhere else, and
-- I remember I wrote this function here.
local function shiftEnterOpt ()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local indentLevel = string.match(vim.api.nvim_get_current_line(), '^%s*[-~]*')
	vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { '', indentLevel .. ' ' })
end

map('n', '<localleader>nr', '<cmd>Neorg return<cr>', Opts('return from Neorg'))
map('n', '<localleader>nc', '<cmd>Neorg toc<cr>', Opts('return from Neorg'))
-- NOTE: This functionality seems already implemented in cor.itero
-- map('i', '<s-cr>', shiftEnterOpt, Opts('instert "-" or "~"'))
-- map('n', '<s-cr>', function() vim.cmd([[normal $]]) vim.cmd([[startinsert]]) vim.api.nvim_input("<right>") shiftEnterOpt() end, Opts('instert "-" or "~"'))
vim.keymap.set('i', '<c-l>', '<c-g>u<Esc>[s1z=`]a<c-g>u', Opts('auto spell fix'))


-- vim.cmd([[
-- Abolish -buffer bc because
-- ]])
