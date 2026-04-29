-- NoetherVim bundle: Octo (GitHub PRs / issues / reviews)
-- Enable with: { import = "noethervim.bundles.tools.octo" }
--
-- GitHub PRs, issues, reviews, and gists inside Neovim.  Pairs with the
-- `git` bundle for full GitHub-flavoured git workflow without leaving
-- the editor.
--
-- Provides:
--   pwntester/octo.nvim    PR / issue / review / gist UI backed by
--                          the GitHub CLI.
--
-- Default keymap:
--   <C-w>O                 :Octo pr list -- main PR list (mirrors the
--                          <C-w>F pattern used by the Fugit2 TUI in the
--                          git bundle).  All other actions are available
--                          via :Octo <Tab> -- pr / issue / review /
--                          gist / repo / search / actions.
--
-- Requirements:
--   • gh CLI: install from https://cli.github.com/, then `gh auth login`
--     once.  Octo shells out to gh for every API call -- no token
--     handling on its end.
--
-- Picker: octo.nvim integrates with snacks.picker via `picker = "snacks"`,
-- matching the rest of NoetherVim's fuzzy-find UI.

return {
	{
		"pwntester/octo.nvim",
		cmd  = "Octo",
		keys = {
			{ "<c-w>O", "<cmd>Octo pr list<cr>", desc = "Octo PR list" },
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"folke/snacks.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			picker          = "snacks",
			use_local_fs    = false,
			enable_builtin  = true,
			default_to_projects_v2 = false,
		},
	},
}
