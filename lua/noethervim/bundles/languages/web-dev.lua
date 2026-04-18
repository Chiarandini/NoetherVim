-- NoetherVim bundle: Web development
-- Enable with: { import = "noethervim.bundles.languages.web-dev" }
--
-- Provides:
--   • template-string.nvim:    auto-convert string → template literal on interpolation
--   • nvim-highlight-colors:   inline color preview for CSS/hex/rgb/hsl/tailwind

return {
	{
		"axelvc/template-string.nvim",
		ft     = { "html", "typescript", "javascript", "typescriptreact", "javascriptreact", "vue", "svelte", "python" },
		opts = {
			filetypes = { "html", "typescript", "javascript", "typescriptreact", "javascriptreact", "vue", "svelte", "python" },
			jsx_brackets          = true,
			remove_template_string = false,
			restore_quotes = {
				normal = [[']],
				jsx    = [["]],
			},
		},
	},

	{ -- inline colour swatches for CSS, hex, rgb, hsl, named colours, tailwind
		"brenoprata10/nvim-highlight-colors",
		ft     = { "css", "html", "javascript", "typescript", "typescriptreact", "javascriptreact", "vue", "svelte", "lua" },
		opts = {
			render                = "virtual",
			virtual_symbol        = "■",
			virtual_symbol_prefix = " ",
			virtual_symbol_suffix = " ",
			virtual_symbol_position = "eow",
			enable_hex            = true,
			enable_rgb            = true,
			enable_hsl            = true,
			enable_var_usage      = true,
			enable_named_colors   = true,
			enable_tailwind       = true,
			exclude_filetypes     = { "lazy" },
			exclude_buftypes      = {},
		},
	},
}
