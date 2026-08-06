---@bundle remote-dev
---@desc distant.nvim SSH editing
---@requires exe=distant label="distant" why="the local half of the connection" install="https://distant.dev/"
---@requires note="distant on the remote host" why="the remote half of the connection" install="ssh host 'curl -L https://sh.distant.dev | sh'"
-- NoetherVim bundle: Remote development (distant.nvim)
-- Enable with: { import = "noethervim.bundles.terminal.remote-dev" }
--
-- Provides distant.nvim for editing files on remote machines over SSH.
-- See: https://distant.dev/editors/neovim/quickstart/
-- Install on remote: ssh host 'curl -L https://sh.distant.dev | sh'
--   :DistantConnect  -- connect to a remote host

return {
	{
		"chipsenkbeil/distant.nvim",
		branch = "v0.3",
		cmd    = "DistantConnect",
		config = function()
			require("distant"):setup()
		end,
	},
}
