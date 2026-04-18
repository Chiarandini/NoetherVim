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
