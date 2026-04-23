-- NoetherVim bundle: Git extras
-- Enable with: { import = "noethervim.bundles.tools.git" }
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
		-- :Gitignore picker using snacks.picker via gitignore.nvim's
		-- custom-picker contract (see its README). The default wiring
		-- hard-depends on telescope; we override M.generate so snacks is
		-- the only UI dependency.  Multi-select with <Tab>; <CR> writes
		-- the combined .gitignore.
		"wintermute-cell/gitignore.nvim",
		cmd          = "Gitignore",
		dependencies = { "folke/snacks.nvim" },
		config = function()
			local gitignore = require("gitignore")
			gitignore.generate = function(opts)
				opts          = opts or {}
				local path    = opts.args or ""
				local overwrite = opts.bang or false
				local items   = {}
				for _, name in ipairs(gitignore.templateNames) do
					table.insert(items, { text = name, _name = name })
				end
				require("snacks").picker({
					title   = ".gitignore templates (<Tab> multi-select)",
					items   = items,
					format  = function(item) return { { item.text } } end,
					confirm = function(picker, item)
						local selected = picker:selected({ fallback = true })
						picker:close()
						local names = {}
						for _, it in ipairs(selected) do
							table.insert(names, it._name or it.text)
						end
						if #names == 0 and item then
							names = { item._name or item.text }
						end
						gitignore.createGitignoreBuffer(path, names, nil, overwrite)
					end,
				})
			end
			-- Re-register :Gitignore so it uses our generate (required per the
			-- gitignore.nvim README).
			vim.api.nvim_create_user_command("Gitignore", gitignore.generate, {
				nargs    = "?",
				complete = "file",
				bang     = true,
			})
		end,
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
