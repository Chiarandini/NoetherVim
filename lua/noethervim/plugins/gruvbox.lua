-- NoetherVim plugin: Gruvbox Colorscheme
-- Ships with core NoetherVim as the default theme.
-- If the colorscheme bundle is enabled, this is redundant (the bundle
-- includes gruvbox among its collection). lazy.nvim merges both specs
-- harmlessly -- no conflict.
return {
	{
		"ellisonleao/gruvbox.nvim",
		lazy = true,
		priority = 1000,
		opts = {},
		config = function(_, opts)
			require("gruvbox").setup(opts)
		end,
	},
}
