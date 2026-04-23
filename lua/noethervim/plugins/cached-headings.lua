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
			-- that snacks-cached-headings requires. We keep it here (even
			-- without loading telescope itself) so the modules are on the
			-- runtime path when snacks_cached_headings is called.
			{
				"Chiarandini/telescope-cached-headings.nvim",
				dependencies = { "nvim-lua/plenary.nvim" },
			},
		},
		cmd  = "SnacksCachedHeadings",
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
	},
}
