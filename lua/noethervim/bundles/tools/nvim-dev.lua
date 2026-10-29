---@bundle nvim-dev
---@desc tooling for working on a Neovim config
---@about :StartupTime benchmarks startup averaged over ten runs, :Luapad
---       gives a live Lua scratchpad, and the vimls server provides
---       completion and diagnostics for legacy .vim files.
---@requires exe=node label="Node.js" why="the vimls server Mason installs"
---          install="https://nodejs.org/" optional=true
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
	-- vimls is in core's enable list (plugins/lsp.lua) and idle until its
	-- binary is installed; this only installs it.
	{ "neovim/nvim-lspconfig",
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			vim.list_extend(opts.ensure_installed, { "vimls" })
		end,
	},

	{
		"dstein64/vim-startuptime",
		cmd  = "StartupTime",
		specs = { { "NoetherVim", optional = true, opts = { g = { startuptime_tries = 10 } } } },
	},
	{ -- interactive Lua scratchpad
		"rafcamlet/nvim-luapad",
		cmd = "Luapad",
		config = function(_, opts)
			require("luapad").setup(opts)
		end,
	},
}
