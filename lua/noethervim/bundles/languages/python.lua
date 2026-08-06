---@bundle python
---@desc virtual environment switching
---@about :VenvSelect finds .venv, venv, conda and poetry environments, points
---       the language server at whichever you pick, and exports VIRTUAL_ENV
---       so terminal commands agree. :VenvSelectCached restores the last
---       choice per project.
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
