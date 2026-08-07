---@bundle c-cpp
---@desc clangd for C and C++, plus the codelldb debug adapter
---@about Installs clangd on demand and adds the C and C++ treesitter parsers.
---       With the debug bundle also enabled, registers the codelldb adapter
---       and launch configurations for both languages.
---@requires note="compile_commands.json"
---          why="clangd resolves includes and flags from it; without one it
---               falls back to guessing and cross-file features degrade"
---          install="CMake writes it with CMAKE_EXPORT_COMPILE_COMMANDS=ON;
---                   Make users usually generate it with bear"
---@requires note="codelldb"
---          why="stepping through C and C++, when the debug bundle is also enabled"
---          install=":MasonInstall codelldb" optional=true
-- NoetherVim bundle: C and C++
-- Enable with: { import = "noethervim.bundles.languages.c-cpp" }
--
-- Provides:
--   • clangd:        C / C++ / Objective-C language server (Mason-installed
--                    only when this bundle is enabled)
--   • c, cpp:        treesitter parsers
--
-- clangd wants a compile_commands.json to know your include paths and flags.
-- Without one it still starts, but completion and diagnostics across headers
-- get noticeably worse, which is the usual cause of "clangd says my includes
-- do not exist".
--
-- Also registers the DAP adapter, but only when tools/debug.lua is enabled
-- too -- see the `optional = true` fragment below.

return {
	-- ── C / C++ LSP (Mason install scoped to this bundle) ──────────────────
	-- Per-server config lives in lua/noethervim/lsp/clangd.lua; that file is
	-- a no-op when the binary isn't installed.
	{ "neovim/nvim-lspconfig",
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			vim.list_extend(opts.ensure_installed, { "clangd" })
		end,
	},

	-- Treesitter is the exception to the list-replacement rule: core declares
	-- `opts_extend = { "ensure_installed" }`, so this appends.
	{ "nvim-treesitter/nvim-treesitter",
		opts = { ensure_installed = { "c", "cpp" } },
	},

	-- ── C / C++ debug adapter ─────────────────────────────────────────────
	-- `optional = true` means lazy.nvim drops this whole fragment unless
	-- nvim-dap is required by something else, i.e. unless tools/debug.lua is
	-- enabled. Enabling this bundle alone installs no debugger.
	--
	-- Registration happens in `opts`, not `config`, and that is deliberate:
	-- lazy.nvim merges `opts` across every fragment of a plugin but lets the
	-- last `config` win outright. The debug bundle already owns nvim-dap's
	-- `config`, so a second one here would silently replace it. Every fragment
	-- opts function runs, and all of them run before that config.
	--
	-- codelldb is resolved by name: Mason prepends its bin directory to PATH,
	-- so `:MasonInstall codelldb` is enough to make this work.
	{
		"mfussenegger/nvim-dap",
		optional = true,
		opts = function()
			local dap = require("dap")

			dap.adapters.codelldb = {
				type = "server",
				port = "${port}",
				executable = {
					command = "codelldb",
					args    = { "--port", "${port}" },
				},
			}

			-- Assigned per key, never as a whole table -- the same discipline
			-- the debug bundle follows, so language bundles don't erase each
			-- other's configurations.
			for _, ft in ipairs({ "c", "cpp" }) do
				dap.configurations[ft] = {
					{
						name    = "Launch file",
						type    = "codelldb",
						request = "launch",
						-- Asked at launch rather than guessed: a C project's
						-- binary has no predictable path relative to the file
						-- you are editing.
						program = function()
							return vim.fn.input("path to executable: ", vim.fn.getcwd() .. "/", "file")
						end,
						cwd         = "${workspaceFolder}",
						stopOnEntry = false,
					},
				}
			end
		end,
	},
}
