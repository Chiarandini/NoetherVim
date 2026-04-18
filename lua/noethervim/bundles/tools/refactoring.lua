-- NoetherVim bundle: Refactoring
-- Enable with: { import = "noethervim.bundles.tools.refactoring" }
--
-- Provides ThePrimeagen/refactoring.nvim for automated refactoring operations.
--   <leader>Re  — extract function        (visual)
--   <leader>Rf  — extract to file         (visual)
--   <leader>Rv  — extract variable        (visual)
--   <leader>Ri  — inline variable         (normal + visual)
--   <leader>Rb  — extract block           (normal)

return {
	{
		"ThePrimeagen/refactoring.nvim",
		cmd    = "Refactor",
		keys   = {
			{ "<leader>Re", function() require("refactoring").refactor("Extract Function") end, mode = "v", desc = "Extract function" },
			{ "<leader>Rf", ":Refactor extract_to_file ",       mode = "x", desc = "Extract to file" },
			{ "<leader>Rv", ":Refactor extract_var ",           mode = "x", desc = "Extract variable" },
			{ "<leader>Ri", ":Refactor inline_var",             mode = { "n", "x" }, desc = "Inline variable" },
			{ "<leader>Rb", ":Refactor extract_block",          mode = "n", desc = "Extract block" },
		},
		config = true,
	},
}
