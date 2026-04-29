-- NoetherVim bundle: Neovim Developer Tools
-- Enable with: { import = "noethervim.bundles.tools.nvim-dev" }
--
-- Provides:
--   :StartupTime     -- benchmark startup (averaged over 10 runs)
--   :Luapad          -- interactive Lua scratchpad buffer
--   vimls LSP        -- completion/diagnostics for legacy .vim files
--                       (Mason-installed only when this bundle is enabled)

return {
	-- ── vimls LSP (Mason install scoped to this bundle) ──────────────────
	-- Per-server config lives in lua/noethervim/lsp/vimls.lua; that file is
	-- a no-op when the binary isn't installed.
	{ "neovim/nvim-lspconfig",
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			vim.list_extend(opts.ensure_installed, { "vimls" })
		end,
	},

	{
		"dstein64/vim-startuptime",
		cmd  = "StartupTime",
		init = function()
			vim.g.startuptime_tries = 10
		end,
	},
	{ -- interactive Lua scratchpad
		"rafcamlet/nvim-luapad",
		cmd = "Luapad",
		config = function()
			require("luapad").setup()
		end,
	},
}
