-- NoetherVim bundle: Git extras
-- Enable with: { import = "noethervim.bundles.git" }
--
-- Provides:
--   • vim-fugitive:   :Git commands, blame, Gread, Gdiffsplit
--   • vim-flog:       git log graph  (:Flog, :Flogsplit)
--   • Fugit2:         TUI git client  (<c-w>F)
--   • diffview.nvim:  diff/history viewer  (<c-w>[d / <c-w>]d)
--   • git-conflict:   conflict markers with resolution actions
--   • gitignore.nvim: generate .gitignore via Telescope  (:Gitignore)

return {

	-- ── vim-fugitive ──────────────────────────────────────────────────────────
	-- :Git blame, :Gread, :Gdiffsplit, :GBrowse, etc.
	{ "tpope/vim-fugitive", event = "VeryLazy" },

	-- ── vim-flog ──────────────────────────────────────────────────────────────
	-- Git log graph viewer.  :Flog / :Flogsplit / :Floggit
	{
		"rbong/vim-flog",
		lazy = true,
		cmd  = { "Flog", "Flogsplit", "Floggit" },
		dependencies = { "tpope/vim-fugitive" },
	},

	{
		"wintermute-cell/gitignore.nvim",
		cmd = "Gitignore",
		dependencies = { "nvim-telescope/telescope.nvim" },
	},
	{
		"SuperBo/fugit2.nvim",
		build = false, -- suppress lua5.1 warning
		opts = {},
		dependencies = {
			"MunifTanjim/nui.nvim",
			"vhyrro/luarocks.nvim",
			"nvim-tree/nvim-web-devicons",
			"nvim-lua/plenary.nvim",
			{
				"chrisgrieser/nvim-tinygit",
				dependencies = { "stevearc/dressing.nvim" },
			},
		},
		cmd  = { "Fugit2", "Fugit2Graph" },
		keys = {
			{ "<c-w>F", "<cmd>Fugit2<cr>", desc = "Fugit2 git UI" },
		},
	},
	{
		"sindrets/diffview.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		keys = {
			{ "<c-w>[d", "<cmd>DiffviewOpen<cr>",                        desc = "DiffView open" },
			{ "<c-w>]d", function() require("diffview").close() end,     desc = "DiffView close" },
		},
		cmd = {
			"DiffviewFileHistory",
			"DiffviewOpen",
			"DiffviewToggleFiles",
			"DiffviewFocusFiles",
			"DiffviewRefresh",
		},
	},
	{
		"akinsho/git-conflict.nvim",
		ft      = {
			"lua", "python", "javascript", "typescript", "typescriptreact",
			"rust", "go", "java", "c", "cpp", "css", "html", "yaml", "toml",
		},
		version = "*",
		config  = true,
	},
}
