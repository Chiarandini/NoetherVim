-- NoetherVim bundle: Presentation / Screensharing
-- Enable with: { import = "noethervim.bundles.practice.presentation" }
--
-- Provides:
--   presenting.nvim:  slide-based presentations from Markdown/Org/AsciiDoc
--     :Presenting      start presentation
--   showkeys:         display keypresses on screen (for screensharing)
--     <c-w>S           toggle keypress display

return {
	{
		"sotte/presenting.nvim",
		cmd = "Presenting",
		opts = {},
	},

	{
		"nvzone/showkeys",
		cmd  = "ShowkeysToggle",
		keys = { { "<c-w>S", "<cmd>ShowkeysToggle<cr>", desc = "Screenkey" } },
		opts = {
			timeout  = 2,
			maxkeys  = 8,
			position = "bottom-center",
		},
	},
}
