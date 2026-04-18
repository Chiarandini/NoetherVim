-- NoetherVim bundle: Better Terminal
-- Enable with: { import = "noethervim.bundles.terminal.better-term" }
--
-- Provides:
--   betterTerm.nvim  — named, numbered terminal windows
--   floaterm         — floating terminal (nvzone/floaterm, note: still beta)
--
-- Key bindings:
--   <c-w><c-t>     — open/toggle primary terminal  (normal + terminal mode)
--   <localleader>t — select a terminal by number    (normal + terminal mode)

return {
	{
		"nvzone/floaterm",
		cmd          = "FloatermToggle",
		dependencies = "nvzone/volt",
		opts         = {},
	},
	{
		"CRAG666/betterTerm.nvim",
		event  = "TermOpen",
		keys   = {
			{
				"<c-w><c-t>",
				function() require("betterTerm").open() end,
				mode = { "n", "t" },
				desc = "Open terminal",
			},
			{
				"<localleader>t",
				function() require("betterTerm").select() end,
				mode = { "n", "t" },
				desc = "Select terminal",
			},
		},
		config = function()
			require("betterTerm").setup()
		end,
	},
}
