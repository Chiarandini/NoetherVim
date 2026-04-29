-- NoetherVim plugin: Editing Enhancements
--  ╔══════════════════════════════════════════════════════════╗
--  ║                   Better file editing                    ║
--  ╚══════════════════════════════════════════════════════════╝

return {
	{ -- vim-matchup: smarter % matching
		"andymass/vim-matchup",
		event = "BufReadPost",
		init = function()
			-- may set any options here
			vim.g.matchup_matchparen_offscreen = { method = "popup" }
		end,
	},


	{ -- https://github.com/kylechui/nvim-surround/blob/main/lua/nvim-surround/config.lua
		"kylechui/nvim-surround",
		event = "VeryLazy",
		opts = {},
		config = function(_, opts)
			-- v4: keymaps no longer set via setup(); defaults apply, then patch the two custom ones
			require("nvim-surround").setup(opts)
			vim.keymap.set("n", "yc", "<Plug>(nvim-surround-normal-cur)",      { desc = "surround current line (was yss)" })
			vim.keymap.set("n", "yC", "<Plug>(nvim-surround-normal-cur-line)", { desc = "surround current line full (was ySS)" })
			pcall(vim.keymap.del, "n", "yss")
			pcall(vim.keymap.del, "n", "ySS")
		end
	},

	--<c-n> in visual mode for multiple cursors
	-- Tutorial: vim -Nu path/to/visual-multi/tutorialrc
	{
		"mg979/vim-visual-multi",
		event = "BufReadPost",
	},

	--  delete extra white space
	{
		"mcauley-penney/tidy.nvim",
		event = 'VeryLazy',
		opts = {
			filetype_exclude = { "snippets", "diff" },
		},
		config = function(_, opts)
			require("tidy").setup(opts)
		end,
	},
	{
		'mcauley-penney/visual-whitespace.nvim',
		config = true,
		-- Lazy-load on the visual-mode entry keys.  desc fields surface in
		-- :NoetherVim diff keymaps so the rows are identifiable.
		keys = {
			{ 'v',     mode = 'n', desc = "visual char mode" },
			{ 'V',     mode = 'n', desc = "visual line mode" },
			{ '<C-v>', mode = 'n', desc = "visual block mode" },
		},
	},

	-- better "." feature
	{ "tpope/vim-repeat", event = "BufReadPost" },
}

