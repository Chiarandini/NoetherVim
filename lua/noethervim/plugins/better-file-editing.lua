--  ╔══════════════════════════════════════════════════════════╗
--  ║                   Better file edditing                   ║
--  ╚══════════════════════════════════════════════════════════╝

-- More advanced example that also highlights diagnostics:
return {
	--https://www.reddit.com/r/neovim/comments/yj2php/lua_alternative_to_vimmatchup/
	--upgrades % key
	{
		"andymass/vim-matchup",
		event = "InsertEnter", -- User ActuallyEditing
		init = function()
			-- may set any options here
			vim.g.matchup_matchparen_offscreen = { method = "popup" }
		end,
	},


	{ -- https://github.com/kylechui/nvim-surround/blob/main/lua/nvim-surround/config.lua
		"kylechui/nvim-surround",
		event = "VeryLazy",
		config = function()
			-- v4: keymaps no longer set via setup(); defaults apply, then patch the two custom ones
			require("nvim-surround").setup()
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
		-- keys = {
		-- 	{'<c-n>',mode = {"i"}},
		-- },
		event = "InsertEnter",
		-- config = function()
		-- setup custom mappings, see :help g:VM_maps
		-- vim.g.VIM_maps = {}

		--If you don't want it enabled in normal mode
		-- vim.g.VM_maps['Find Under'] = ''
		-- end
	},

	--  delete extra white space
	{
		"mcauley-penney/tidy.nvim",
		event = 'VeryLazy',
		-- event = "BufWritePre",
		config = function()
			-- [oT/]oT: tidy whitespace trimmer (option on/off convention)
			vim.keymap.set("n", "[oD", function() require("tidy").enable()  end, { desc = "tidy ON  (oD = remove Dirty whitespace)" })
			vim.keymap.set("n", "]oD", function() require("tidy").disable() end, { desc = "tidy OFF (oD = remove Dirty whitespace)" })
			require("tidy").setup({
				filetype_exclude = { "snippets", "diff" },
			})
		end,
	},
	{
		'mcauley-penney/visual-whitespace.nvim',
		config = true,
		keys = { 'v', 'V', '<C-v>' }, -- optionally, lazy load on visual mode keys
	},

	-- better "." feature
	{ "tpope/vim-repeat", event = "BufReadPost" },

	{ -- for nice little side scroll bar with minimal LSP info (Satellite may eventually replace)
		'petertriho/nvim-scrollbar',
		event = "VeryLazy",
		config = function()
			require("scrollbar").setup({
				excluded_filetypes = {
					"cmp_docs", "cmp_menu", "noice", "prompt",
					"neo-tree", "NvimTree", "neo-tree-popup",
					"lazy", "alpha", "TelescopePrompt", "mpv",
				},
			})
		end
	}
}

