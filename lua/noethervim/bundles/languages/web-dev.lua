-- NoetherVim bundle: Web development
-- Enable with: { import = "noethervim.bundles.languages.web-dev" }
--
-- Provides:
--   • template-string.nvim:    auto-convert string → template literal on interpolation
--   • nvim-highlight-colors:   inline color preview for CSS/hex/rgb/hsl/tailwind
--   • ts_ls, cssls, eslint:    TypeScript / CSS / ESLint LSPs (Mason-installed
--                              only when this bundle is enabled)

return {
	-- ── Web LSPs (Mason install scoped to this bundle) ─────────────────────
	-- Per-server config lives in lua/noethervim/lsp/{ts_ls,cssls,eslint}.lua;
	-- those files are no-ops when the binaries aren't installed.
	{ "neovim/nvim-lspconfig",
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			vim.list_extend(opts.ensure_installed, { "ts_ls", "cssls", "eslint" })
		end,
	},

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
