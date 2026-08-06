---@bundle helpview
---@desc rendered :help pages
---@about Renders Neovim's help files with real formatting, headings and
---       tables via treesitter, instead of plain fixed-width text.
---@requires none
-- NoetherVim bundle: Helpview
-- Enable with: { import = "noethervim.bundles.ui.helpview" }
--
-- Renders Neovim :help pages with rich formatting via treesitter.

return {
	{
		"OXY2DEV/helpview.nvim",
		ft           = "help",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
	},
}
