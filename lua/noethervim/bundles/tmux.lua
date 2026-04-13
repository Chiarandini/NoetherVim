-- NoetherVim bundle: Tmux integration
-- Enable with: { import = "noethervim.bundles.tmux" }
--
-- Provides:
--   only-tmux.nvim:         automatic tmux window naming based on session
--   vim-tmux-navigator:     seamless navigation between Neovim and tmux panes
--                            (<C-h/j/k/l> to move between splits and panes)

return {
	{
		"karshPrime/only-tmux.nvim",
		event  = "VeryLazy",
		config = { new_window_name = "session" },
	},
	{
		"christoomey/vim-tmux-navigator",
		event = "VeryLazy",
	},
}
