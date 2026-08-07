---@bundle python
---@desc virtual environment switching
---@about :VenvSelect finds .venv, venv, conda and poetry environments, points
---       the language server at whichever you pick, and exports VIRTUAL_ENV
---       so terminal commands agree. :VenvSelectCached restores the last
---       choice per project. With the debug bundle also enabled, registers
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
--   :VenvSelect        pick a venv (searches for .venv, venv, conda, poetry, etc.)
--   :VenvSelectCached  re-select last used venv for this project
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
		cmd = { "VenvSelect", "VenvSelectCached" },
		ft = "python",
		opts = {},
	},

	-- ── Python debug adapter ──────────────────────────────────────────────
	-- `optional = true` means lazy.nvim drops this whole fragment unless
	-- nvim-dap is required by something else, i.e. unless tools/debug.lua is
	-- enabled. Enabling this bundle alone installs no debugger.
	--
	-- dap-python.setup() with no argument launches the adapter with `python3`
	-- from PATH; the interpreter the debuggee runs under is resolved per
	-- session from VIRTUAL_ENV / CONDA_PREFIX, which is exactly what
	-- venv-selector above sets.
	{
		"mfussenegger/nvim-dap",
		optional = true,
		dependencies = {
			{
				"mfussenegger/nvim-dap-python",
				ft = "python",
				config = function()
					require("dap-python").setup()
				end,
			},
		},
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
