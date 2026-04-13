-- NoetherVim bundle: Task Runner
-- Enable with: { import = "noethervim.bundles.task-runner" }
--
-- Provides:
--   overseer.nvim:    task runner  (:OverseerRun, :OverseerToggle)
--   compiler.nvim:    project compiler UI  (:CompilerOpen, :CompilerToggleResults)

return {
	{
		"stevearc/overseer.nvim",
		cmd  = { "OverseerRun", "OverseerToggle" },
		opts = {},
	},

	{
		"Zeioth/compiler.nvim",
		cmd          = { "CompilerOpen", "CompilerToggleResults", "CompilerRedo" },
		dependencies = { "stevearc/overseer.nvim", "nvim-telescope/telescope.nvim" },
		opts         = {},
	},
}
