-- NoetherVim plugin: Join/Split Lines
-- Treesitter-aware join/split: [j to join, ]j to split.
return {
	'Wansmer/treesj',
	keys = {
		{ '[j', function() require('treesj').join() end,  desc = "[j]oin lines (*not* split)" },
		{ ']j', function() require('treesj').split() end, desc = "un[j]oin lines (split)" },
	},
	dependencies = { 'nvim-treesitter/nvim-treesitter' },
	opts = {
		use_default_keymaps = false,
		check_syntax_error = true,
		max_join_length = 300,
		cursor_behavior = 'hold',
		notify = true,
		dot_repeat = true,
	},
}
