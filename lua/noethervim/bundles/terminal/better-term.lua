---@bundle better-term
---@desc named and numbered terminal windows
---@about Terminals you can name, number and return to, rather than one
---       anonymous split. Includes a floating terminal, and bindings to
---       toggle the primary terminal or select one by number from both normal
---       and terminal mode.
---@requires none
-- NoetherVim bundle: Better Terminal
-- Enable with: { import = "noethervim.bundles.terminal.better-term" }
--
-- Provides:
--   betterTerm.nvim  -- named, numbered terminal windows
--   floaterm         -- floating terminal (nvzone/floaterm, note: still beta)
--
-- Key bindings:
--   <c-w><c-t>     -- open/toggle primary terminal  (normal + terminal mode)
--   <localleader>t -- select a terminal by number    (normal + terminal mode)

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
