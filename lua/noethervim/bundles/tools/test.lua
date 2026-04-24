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
