-- NoetherVim bundle: Refactoring
-- Enable with: { import = "noethervim.bundles.refactoring" }
--
-- Provides ThePrimeagen/refactoring.nvim for automated refactoring operations.
--   <leader>re  — extract function        (visual)
--   <leader>rf  — extract to file         (visual)
--   <leader>rv  — extract variable        (visual)
--   <leader>ri  — inline variable         (normal + visual)
--   <leader>rb  — extract block           (normal)

return {
	{
		"ThePrimeagen/refactoring.nvim",
		cmd    = "Refactor",
		keys   = {
			{ "<leader>re", function() require("refactoring").refactor("Extract Function") end, mode = "v", desc = "Extract function" },
			{ "<leader>rf", ":Refactor extract_to_file ",       mode = "x", desc = "Extract to file" },
			{ "<leader>rv", ":Refactor extract_var ",           mode = "x", desc = "Extract variable" },
			{ "<leader>ri", ":Refactor inline_var",             mode = { "n", "x" }, desc = "Inline variable" },
			{ "<leader>rb", ":Refactor extract_block",          mode = "n", desc = "Extract block" },
		},
		config = true,
	},
}
