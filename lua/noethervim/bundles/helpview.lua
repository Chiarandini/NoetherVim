-- NoetherVim bundle: Helpview
-- Enable with: { import = "noethervim.bundles.helpview" }
--
-- Renders Neovim :help pages with rich formatting via treesitter.

return {
	{
		"OXY2DEV/helpview.nvim",
		ft           = "help",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
	},
}
