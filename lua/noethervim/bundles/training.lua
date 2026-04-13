-- NoetherVim bundle: Training
-- Enable with: { import = "noethervim.bundles.training" }
--
-- Vim/typing practice games — all lazy-loaded by command.
--   :VimBeGood         vim-be-good  (motion practice)
--   :Speedtyper        speedtyper.nvim  (typing speed)
--   :Typr / :TyprStats typr  (typing practice)

return {
	{
		"ThePrimeagen/vim-be-good",
		cmd = "VimBeGood",
	},
	{
		"NStefan002/speedtyper.nvim",
		branch = "main",
		cmd    = "Speedtyper",
		opts   = {},
	},
	{
		"nvzone/typr",
		dependencies = "nvzone/volt",
		opts         = {},
		cmd          = { "Typr", "TyprStats" },
	},
}
