-- NoetherVim plugin: Cached Headings (snacks)
--
-- Headings picker for tex / markdown / org files. Uses Snacks.picker as the
-- UI and shares the on-disk cache with Chiarandini/telescope-cached-headings
-- so both pickers stay in sync when telescope is present.
--
-- Override any value in opts via a user plugin spec:
--   { "Chiarandini/snacks-cached-headings.nvim",
--     opts = { auto_update = false } }

local SearchLeader = require("noethervim.util").search_leader

return {
	{
		"Chiarandini/snacks-cached-headings.nvim",
		dependencies = {
			"folke/snacks.nvim",
			"Chiarandini/latex-nav-core.nvim",
			-- telescope-cached-headings.nvim provides the cache / parser /
			-- utils modules under `telescope._extensions.cached_headings.*`
			-- and registers :CachedHeadingsUpdate / :CachedHeadingsWipeAll.
			{
				"Chiarandini/telescope-cached-headings.nvim",
				dependencies = { "nvim-lua/plenary.nvim" },
			},
			-- Telescope itself is required to trigger the extension's
			-- `load_extension` callback, which is where the user commands
			-- above get registered. Transitional: when those commands are
			-- ported out of the telescope extension (see
			-- dev-docs/telescope-removal-plan.md phase 4 cleanup), this
			-- dep can be dropped.
			"nvim-telescope/telescope.nvim",
		},
		cmd  = { "SnacksCachedHeadings", "CachedHeadingsUpdate", "CachedHeadingsWipeAll" },
		keys = {
			{ SearchLeader .. "t", "<cmd>SnacksCachedHeadings<cr>", desc = "headings" },
		},
		opts = {
			-- Match telescope-cached-headings defaults so users get
			-- identical behaviour between the two pickers.
			scan_includes   = true,
			include_starred = true,
			recursive_limit = 3,
			auto_update     = true,
		},
		config = function(_, opts)
			require("snacks_cached_headings").setup(opts)
			-- Register the :CachedHeadings* user commands. telescope is
			-- loaded for this purpose only; the picker itself uses snacks.
			pcall(function()
				require("telescope").load_extension("cached_headings")
			end)
		end,
	},
}
