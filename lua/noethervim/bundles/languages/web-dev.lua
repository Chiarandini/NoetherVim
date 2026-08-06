---@bundle web-dev
---@desc TypeScript, CSS and ESLint servers
---@about Installs the ts_ls, cssls and eslint language servers on demand, and
---       adds two editing aids: strings convert to template literals as soon
---       as you interpolate, and CSS, hex, rgb, hsl and Tailwind colors
---       preview inline.
---@requires exe=node label="Node.js"
---          why="the ts_ls, cssls and eslint servers Mason installs"
---          install="https://nodejs.org/"
---@requires exe=npm label="npm"
---          why="building vscode-js-debug, when the debug bundle is also enabled"
---          install="ships with Node.js" optional=true
-- NoetherVim bundle: Web development
-- Enable with: { import = "noethervim.bundles.languages.web-dev" }
--
-- Provides:
--   • template-string.nvim:    auto-convert string → template literal on interpolation
--   • nvim-highlight-colors:   inline color preview for CSS/hex/rgb/hsl/tailwind
--   • ts_ls, cssls, eslint:    TypeScript / CSS / ESLint LSPs (Mason-installed
--                              only when this bundle is enabled)
--
-- Also registers the JavaScript/TypeScript DAP adapter, but only when
-- tools/debug.lua is enabled too -- see the `optional = true` fragment below.

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

	-- ── JavaScript / TypeScript debug adapter ─────────────────────────────
	-- `optional = true` means lazy.nvim drops this whole fragment unless
	-- nvim-dap is required by something else, i.e. unless tools/debug.lua is
	-- enabled. That gating is what keeps the cost proportionate:
	-- vscode-js-debug is ~430 MB and its `build` step runs `npm i` at install
	-- time, which is only worth paying for by someone who writes JavaScript.
	{
		"mfussenegger/nvim-dap",
		optional = true,
		dependencies = {
			{
				"microsoft/vscode-js-debug",
				lazy    = true,
				version = "1.x",
				build   = "npm i && npm run compile vsDebugServerBundle && mv dist out",
			},
			{
				"mxsdev/nvim-dap-vscode-js",
				lazy = true,
				opts = {
					debugger_path = vim.fn.stdpath("data") .. "/lazy/vscode-js-debug",
					adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
				},
				config = function(_, opts)
					require("dap-vscode-js").setup(opts)

					-- `${workspaceFolder}` is resolved by nvim-dap per session,
					-- so the debuggee runs from wherever the session starts.
					-- A literal `vim.fn.getcwd()` here would be evaluated once,
					-- at plugin load, and freeze that directory.
					local dap = require("dap")
					for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
						dap.configurations[ft] = {
							{
								type = "pwa-node", name = "Launch file", request = "launch",
								program = "${file}", cwd = "${workspaceFolder}",
								sourceMaps = true, protocol = "inspector", console = "integratedTerminal",
							},
							{
								type = "pwa-node", name = "Attach to process", request = "attach",
								processId = require("dap.utils").pick_process, cwd = "${workspaceFolder}",
								sourceMaps = true, protocol = "inspector", console = "integratedTerminal",
							},
						}
					end
				end,
			},
		},
	},
}
