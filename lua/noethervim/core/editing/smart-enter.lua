-- NoetherVim plugin: smart-enter.nvim

return {
	-- smart-enter.nvim: context dispatched <S-CR>. Owns the global insert
	-- mode <S-CR> (a newline that skips the comment leader) and continues
	-- Markdown lists. The latex bundle merges in LaTeX environment rules.
	--
	-- markdown and shell are configured here rather than in a bundle because
	-- both are edited regardless of which language bundles are enabled: every
	-- repo has a README and an install script. Bundle-gated languages keep
	-- their rules in the bundle, as latex does.
	{
		"Chiarandini/smart-enter.nvim",
		lazy = true,
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("smart-enter.nvim", {
			{ "<S-CR>", function() require("smart_enter").dispatch() end, mode = "i", silent = true, desc = "smart enter" },
		}) } },
		opts = {
			key      = false,
			fallback = "newline",
			filetypes = {
				markdown = { preset = "markdown" },
				-- sh covers .sh, .bash, and every bash/sh shebang; zsh is
				-- its own filetype. There is no `bash` filetype to add.
				sh       = { preset = "shell" },
				zsh      = { preset = "shell" },
			},
		},
		config = function(_, opts)
			require("smart_enter").setup(opts)
		end,
	},
}
