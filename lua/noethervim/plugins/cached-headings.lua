-- NoetherVim plugin: Cached Headings (snacks)
--
-- Headings picker for tex / markdown / org files. Uses Snacks.picker as the
-- UI; cache/parser/latex helpers all come from latex-nav-core. The plugin
-- registers its own user commands during setup() -- see the upstream readme
-- for the full surface (`:SnacksCachedHeadings`, `:CachedHeadings update|wipe`).

local SearchLeader = require("noethervim.util").search_leader

return {
	{
		"Chiarandini/snacks-cached-headings.nvim",
		dependencies = {
			"folke/snacks.nvim",
			"Chiarandini/latex-nav-core.nvim",
		},
		cmd  = { "SnacksCachedHeadings", "CachedHeadings" },
		keys = {
			{ SearchLeader .. "t", "<cmd>SnacksCachedHeadings<cr>", desc = "headings" },
		},
		opts = {
			scan_includes   = true,
			include_starred = true,
			recursive_limit = 3,
			auto_update     = true,
			allowed_filetypes = { "tex", "markdown", "org" },
			cache_strategy    = "global",
			notify_on_update  = true,
		},
		config = function(_, opts)
			require("snacks_cached_headings").setup(opts)
		end,
	},
}
