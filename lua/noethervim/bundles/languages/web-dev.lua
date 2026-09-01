---@bundle web-dev
---@desc TypeScript, CSS and ESLint servers
---@about Installs the ts_ls, cssls and eslint language servers on demand, and
---       adds two editing aids: strings convert to template literals as soon
---       as you interpolate, and CSS, hex, rgb, hsl and Tailwind colors
---       preview inline. With the test bundle also enabled, registers the
---       Jest and Vitest adapters.
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
-- Also registers the JavaScript/TypeScript DAP adapter and the Jest and
-- Vitest test adapters, but only when tools/debug.lua and tools/test.lua are
-- enabled too -- see the `optional = true` fragments below.

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

	-- The parsers arrived via core's `auto_install` before, which works but
	-- states no dependency: nothing recorded that this bundle needs them, so
	-- nothing would notice if auto_install were turned off.
	{ "nvim-treesitter/nvim-treesitter",
		opts = { ensure_installed = {
			"typescript", "javascript", "tsx", "css", "html", "json",
		} },
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
	-- enabled.
	--
	-- js-debug ships two servers and the difference is not cosmetic.
	-- `vsDebugServer` is the VS Code flavour: it expects the editor to answer a
	-- `startDebugging` reverse request and run the debuggee in a child session.
	-- Against nvim-dap that request never arrived, so the child session was
	-- never created, nothing ever stopped, and a breakpoint did nothing --
	-- including with `stopOnEntry`, because the session that would stop did not
	-- exist. `dapDebugServer` is the standalone-DAP entry point and speaks to a
	-- plain DAP client directly.
	--
	-- Mason's `js-debug-adapter` package is that release, which also retires a
	-- ~430 MB source checkout whose `build` ran `npm i` at install time.
	{
		"mfussenegger/nvim-dap",
		optional = true,
		opts = function(_, opts)
			opts.mason_install = opts.mason_install or {}
			table.insert(opts.mason_install, "js-debug-adapter")

			local dap = require("dap")
			local server = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages",
				"js-debug-adapter", "js-debug", "src", "dapDebugServer.js")

			-- One server backs every js-debug adapter type; they differ only in
			-- the `type` a configuration names.
			for _, name in ipairs({ "pwa-node", "pwa-chrome", "pwa-msedge",
			                        "node-terminal", "pwa-extensionHost" }) do
				dap.adapters[name] = {
					type = "server",
					host = "localhost",
					port = "${port}",
					executable = { command = "node", args = { server, "${port}" } },
				}
			end

			-- `${workspaceFolder}` is resolved by nvim-dap per session, so the
			-- debuggee runs from wherever the session starts. A literal
			-- `vim.fn.getcwd()` here would be evaluated once, at load, and
			-- freeze that directory.
			for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
				dap.configurations[ft] = {
					{
						type = "pwa-node", name = "Launch file", request = "launch",
						program = "${file}", cwd = "${workspaceFolder}",
						sourceMaps = true, protocol = "inspector",
					},
					{
						type = "pwa-node", name = "Attach to process", request = "attach",
						processId = require("dap.utils").pick_process, cwd = "${workspaceFolder}",
						sourceMaps = true, protocol = "inspector",
					},
				}
			end
		end,
	},

	-- ── JavaScript / TypeScript test adapters ─────────────────────────────
	-- Same `optional = true` gating, against tools/test.lua. Both adapters
	-- are registered rather than one: Jest and Vitest are the two runners in
	-- common use, each detects its own project layout and stays quiet in a
	-- project that is not using it, so picking one here would be choosing a
	-- test runner on the user's behalf for no gain.
	--
	-- Built in an `opts` function so the `require` runs after the adapter
	-- plugin loads; see tools/test.lua for why `adapters` merges as it does.
	{
		"nvim-neotest/neotest",
		optional = true,
		dependencies = {
			"nvim-neotest/neotest-jest",
			"marilari88/neotest-vitest",
		},
		opts = function(_, opts)
			opts.adapters = opts.adapters or {}
			table.insert(opts.adapters, require("neotest-jest")({}))
			table.insert(opts.adapters, require("neotest-vitest"))
		end,
	},
}
