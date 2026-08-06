---@bundle test
---@desc run tests and see results against the code
---@about The neotest framework, with results shown beside the code they
---       cover. No adapter is enabled by default; add the one for your
---       language in lua/user/plugins/. neotest-python ships alongside it.
---@requires exe=python3 label="Python 3"
---          why="neotest-python is the shipped adapter"
---          install="then pip install pytest" optional=true
-- NoetherVim bundle: Test Runner
-- Enable with: { import = "noethervim.bundles.tools.test" }
--
-- Provides neotest -- a test runner framework.
-- No adapters are configured by default -- add them in user plugins:
--
--   return {
--     "nvim-neotest/neotest",
--     dependencies = { "nvim-neotest/neotest-python" },
--     opts = { adapters = { require("neotest-python")({...}) } },
--   }

return {
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		cmd    = { "Neotest" },
		opts = { adapters = {} },
	},
}
