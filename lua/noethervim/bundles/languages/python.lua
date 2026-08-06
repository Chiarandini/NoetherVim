---@bundle python
---@desc venv-selector -- virtual environment switching
---@requires exe=python3 label="Python 3" why="virtual-environment discovery" install="https://www.python.org/downloads/"
-- NoetherVim bundle: Python
-- Enable with: { import = "noethervim.bundles.languages.python" }
--
-- Provides venv-selector.nvim -- virtual environment switching.
--   :VenvSelect        pick a venv (searches for .venv, venv, conda, poetry, etc.)
--   :VenvSelectCached  re-select last used venv for this project
--
-- Automatically reconfigures the LSP (pyright/basedpyright) to use the
-- selected environment and sets VIRTUAL_ENV for terminal commands.

return {
	{
		"linux-cultist/venv-selector.nvim",
		dependencies = { "neovim/nvim-lspconfig" },
		cmd = { "VenvSelect", "VenvSelectCached" },
		ft = "python",
		opts = {},
	},
}
