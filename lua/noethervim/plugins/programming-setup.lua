-- NoetherVim plugin: Programming Utilities
--  ╔══════════════════════════════════════════════════════════╗
--  ║                       programming                        ║
--  ╚══════════════════════════════════════════════════════════╝

return {
	{
		-- context-smart comment adder
		"danymat/neogen",
		keys = {
			{
				"<leader>Rd",
				function()
					require("neogen").generate({})
				end,
				desc = "[R]efactor: generate [d]oc comment",
				noremap = true,
				silent = true,
			},
		},
		dependencies = "nvim-treesitter/nvim-treesitter",
		opts = {
			snippet_engine = "luasnip",
		},
		-- Uncomment next line if you want to follow only stable versions
		-- version = "*"
	},
	-- better around/in operators
	{
		"echasnovski/mini.ai",
		version = false,
		event = "BufReadPost",
		opts = {},
	},

	-- For pop-up
	{
		"kevinhwang91/nvim-bqf",
		ft = "qf",
	},

	{ -- when oppening nvim in a terminal in nvim, opens it in new buffer
		"willothy/flatten.nvim",
		config = true,
		event = "TermOpen",
		-- or pass configuration with
		-- opts = {  }
		-- Ensure that it runs first to minimize delay when opening file from terminal
		priority = 1001,
	},

	{ -- better marks visualization
		"chentoast/marks.nvim",
		event = "BufReadPost",
		opts = {
			default_mappings = true,
			builtin_marks = {},
			cyclic = true,
			force_write_shada = false,
			refresh_interval = 250,
			sign_priority = { lower=10, upper=15, builtin=8, bookmark=20 },
			excluded_filetypes = {},
			excluded_buftypes = {},
			bookmark_0 = {
				sign = "⚑",
				virt_text = "hello world",
				annotate = false,
			},
			mappings = {},
		},
	},

}
