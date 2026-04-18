-- NoetherVim bundle: Smart Actions
-- Enable with: { import = "noethervim.bundles.smart-actions" }
--
-- AI-suggested code actions, separate from stock LSP gra. Press grA on a
-- symbol; pick a scope (or set default_scope); review fixes in the
-- picker's inline diff preview; <CR> applies, `e` hand-edits, <Esc>
-- dismisses. Every apply is a single undo unit.
--
-- Provider resolution (auto-detected):
--   1. `claude` CLI on $PATH (reuses your Claude Code auth)
--   2. Anthropic API — ANTHROPIC_API_KEY in env or lua/secrets.lua
--
-- Override via user/plugins/ to force a provider or change default scope:
--   { "Chiarandini/smart-actions.nvim", opts = {
--       provider      = "anthropic",
--       default_scope = "function",
--   } }
--
-- See :help smart-actions for the full surface (categories, context,
-- extension points, known limitations).

return {
	{
		"Chiarandini/smart-actions.nvim",
		keys = {
			{ "grA", function() require("smart_actions").run() end,
				mode = { "n", "x" }, desc = "smart code [A]ction" },
		},
		cmd = { "SmartAction", "SmartActionCancel", "SmartActionLastDiff" },
		opts = {
			default_scope = "ask",
			categories = { "quickfix" },
		},
		config = function(_, opts)
			require("smart_actions").setup(opts)
		end,
	},
}
