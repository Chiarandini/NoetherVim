local function comment_yank_paste()
	local win = vim.api.nvim_get_current_win()
	local cur = vim.api.nvim_win_get_cursor(win)
	local vstart = vim.fn.getpos("v")[2]
	local current_line = vim.fn.line(".")
	local set_cur = vim.api.nvim_win_set_cursor
	if vstart == current_line then
		vim.cmd.yank()
		require("Comment.api").toggle.linewise.current()
		vim.cmd.put()
		set_cur(win, { cur[1] + 1, cur[2] })
	else
		if vstart < current_line then
			vim.cmd(":" .. vstart .. "," .. current_line .. "y")
			vim.cmd.put()
			set_cur(win, { vim.fn.line("."), cur[2] })
		else
			vim.cmd(":" .. current_line .. "," .. vstart .. "y")
			set_cur(win, { vstart, cur[2] })
			vim.cmd.put()
			set_cur(win, { vim.fn.line("."), cur[2] })
		end
		require("Comment.api").toggle.linewise(vim.fn.visualmode())
	end
end
-- adding comments quickly
return{'numToStr/Comment.nvim',
keys  =
	{
		{'<C-/>', function() require('Comment.api').toggle.linewise.current() end, desc='toggle commented'},
		{'', function() require('Comment.api').toggle.linewise.current() end},
		{
			'<C-/>',
			function()
				local esc = vim.api.nvim_replace_termcodes( '<ESC>', true, false, true)
				local comment = require('Comment.api')
				vim.api.nvim_feedkeys(esc, 'nx', false)
				comment.toggle.linewise(vim.fn.visualmode())
			end,
			mode = {'x', 'v'},
			desc =  'toggle commented'
		},
		{
			'',
			function()
				local esc = vim.api.nvim_replace_termcodes( '<ESC>', true, false, true)
				local comment = require('Comment.api')
				vim.api.nvim_feedkeys(esc, 'nx', false)
				comment.toggle.linewise(vim.fn.visualmode())
			end,
			mode = {'x', 'v'},
			desc =  'toggle commented'
		},
		{'<c-s-r>', comment_yank_paste, mode = {'n', 'v', 'x'}, desc = 'comment and paste text'},
	},
	config = function()
		require('Comment').setup()
	end
}
