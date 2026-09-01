---@bundle python
---@desc virtual environment switching
---@about :VenvSelect finds .venv, venv, conda and poetry environments, points
---       the language server at whichever you pick, and exports VIRTUAL_ENV
---       so terminal commands agree; the last choice is remembered and
---       reactivated per project. With the debug bundle also enabled, registers
---       the debugpy adapter against that same environment; with the test
---       bundle, the neotest-python adapter.
---@requires exe=python3 label="Python 3" why="virtual-environment discovery"
---          install="https://www.python.org/downloads/"
---@requires note="debugpy"
---          why="stepping through Python, when the debug bundle is also enabled"
---          install="pip install debugpy, into the environment you debug"
---          optional=true
---@requires note="pytest"
---          why="running Python tests, when the test bundle is also enabled"
---          install="pip install pytest, into the environment you test"
---          optional=true
-- NoetherVim bundle: Python
-- Enable with: { import = "noethervim.bundles.languages.python" }
--
-- Provides venv-selector.nvim -- virtual environment switching.
--   :VenvSelect  pick a venv (.venv, venv, conda, poetry, etc.); the last
--                selection is remembered and reactivated per project
--
-- Automatically reconfigures the LSP (pyright/basedpyright) to use the
-- selected environment and sets VIRTUAL_ENV for terminal commands.
--
-- Also registers the DAP and neotest adapters, but only when tools/debug.lua
-- and tools/test.lua are enabled too -- see the `optional = true` fragments
-- below.

return {
	{
		"linux-cultist/venv-selector.nvim",
		dependencies = { "neovim/nvim-lspconfig" },
		cmd = { "VenvSelect" },
		ft = "python",
		opts = {},
	},

	{ "nvim-treesitter/nvim-treesitter",
		opts = { ensure_installed = { "python", "toml" } },
	},

	-- basedpyright and ruff are in core's `ensure_installed`, so the language
	-- server half is already covered; black is not, and core does not claim
	-- the filetype it cannot install for.
	{ "stevearc/conform.nvim",
		opts = function(_, opts)
			opts.formatters_by_ft = opts.formatters_by_ft or {}
			opts.formatters_by_ft.python = { "black" }
			opts.mason_install = opts.mason_install or {}
			table.insert(opts.mason_install, "black")
		end,
	},

	-- ── Python debug adapter ──────────────────────────────────────────────
	-- `optional = true` means lazy.nvim drops this whole fragment unless
	-- nvim-dap is required by something else, i.e. unless tools/debug.lua is
	-- enabled. Enabling this bundle alone installs no debugger.
	--
	-- Two interpreters are in play and they are not the same one. The argument
	-- to setup() is the interpreter that RUNS THE ADAPTER, and it must be able
	-- to `import debugpy`; the interpreter the DEBUGGEE runs under is resolved
	-- per session from VIRTUAL_ENV / CONDA_PREFIX, which is what venv-selector
	-- above sets, and is untouched by this.
	--
	-- Calling setup() with no argument points the adapter at `python3` from
	-- PATH, which on a normal machine cannot import debugpy: Mason installs it
	-- into its own venv. The result is a registered adapter, an installed
	-- package, and a debugger that never starts. Point it at the venv Mason
	-- actually filled, and fall back to `python3` for someone who installed
	-- debugpy themselves.
	{
		"mfussenegger/nvim-dap",
		optional = true,
		dependencies = {
			{
				"mfussenegger/nvim-dap-python",
				ft = "python",
				config = function()
					local mason_python = vim.fs.joinpath(vim.fn.stdpath("data"),
						"mason", "packages", "debugpy", "venv", "bin", "python")
					require("dap-python").setup(
						vim.uv.fs_stat(mason_python) and mason_python or "python3")
				end,
			},
		},
		-- Mason's debugpy is a standalone copy, which is the right one for the
		-- adapter process itself; the debuggee still runs under whichever
		-- interpreter :VenvSelect exported.
		opts = function(_, opts)
			opts.mason_install = opts.mason_install or {}
			table.insert(opts.mason_install, "debugpy")
		end,
	},

	-- ── Python test adapter ───────────────────────────────────────────────
	-- Same `optional = true` gating against tools/test.lua.
	--
	-- Built in an `opts` function so the `require` runs after the adapter
	-- plugin loads; see tools/test.lua for why `adapters` merges as it does.
	--
	-- neotest-python resolves the interpreter from $VIRTUAL_ENV first, then
	-- a project-local venv, which is exactly what :VenvSelect above exports.
	-- It memoises that answer per project root, so switching venv mid-session
	-- needs a restart before tests follow the new one.
	{
		"nvim-neotest/neotest",
		optional = true,
		dependencies = { "nvim-neotest/neotest-python" },
		opts = function(_, opts)
			opts.adapters = opts.adapters or {}
			table.insert(opts.adapters, require("neotest-python")({}))
		end,
	},
}
