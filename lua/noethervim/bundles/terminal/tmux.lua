---@bundle tmux
---@desc tmux pane navigation and window naming
---@about <C-h/j/k/l> moves between Neovim splits and tmux panes without
---       caring which is which, and tmux window names follow the Neovim
---       session automatically.
---@requires exe=tmux label="tmux" why="pane navigation and window naming" install="brew install tmux, or your package manager"
-- NoetherVim bundle: Tmux integration
-- Enable with: { import = "noethervim.bundles.terminal.tmux" }
--
-- Provides:
--   only-tmux.nvim:         automatic tmux window naming based on session
--   vim-tmux-navigator:     seamless navigation between Neovim and tmux panes
--                            (<C-h/j/k/l> to move between splits and panes)

return {
	{
		"karshPrime/only-tmux.nvim",
		event  = "VeryLazy",
		opts = { new_window_name = "session" },
	},
	{
		"christoomey/vim-tmux-navigator",
		event = "VeryLazy",
	},
}
