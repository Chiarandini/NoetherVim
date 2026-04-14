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
		opts = {
			task_list = {
				keymaps = {
					-- defaults use <C-j>/<C-k> which conflict with window navigation
					["<C-j>"] = false,
					["<C-k>"] = false,
					["<C-d>"] = "keymap.scroll_output_down",
					["<C-u>"] = "keymap.scroll_output_up",
				},
			},
		},
	},

	{
		"Zeioth/compiler.nvim",
		cmd          = { "CompilerOpen", "CompilerToggleResults", "CompilerRedo" },
		dependencies = { "stevearc/overseer.nvim", "nvim-telescope/telescope.nvim" },
		opts         = {},
	},
}
