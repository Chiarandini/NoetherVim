-- NoetherVim plugin: Undo Tree
-- Undo tree with floating diff preview. Toggle: <C-w><C-u>
return {
	{
		"jiaoshijie/undotree",
		cmd = "UndotreeToggle",
		keys = {
			{ "<c-w><c-u>", function() require('undotree').toggle() end , desc = "Toggle Undo Tree" },
		},
		opts = {
			float_diff = true,
			layout = "left_bottom",
			ignore_filetype = { 'undotree', 'undotreeDiff', 'qf', 'TelescopePrompt', 'spectre_panel', 'tsplayground' },
			window = { winblend = 30 },
			keymaps = {
				['j'] = "move_next",  ['k'] = "move_prev",
				['gj'] = "move2parent",
				['J'] = "move_change_next", ['K'] = "move_change_prev",
				['<cr>'] = "action_enter", ['p'] = "enter_diffbuf", ['q'] = "quit",
			},
		},
		dependencies = { "nvim-lua/plenary.nvim", },
	}
}
