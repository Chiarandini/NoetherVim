-- NoetherVim bundle: Smart Actions
-- Enable with: { import = "noethervim.bundles.tools.smart-actions" }
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
-- Statusline integration: while a request is in flight the NoetherVim
-- Busy component is recoloured and labelled "ai" (via the
-- register_busy_override hook). User config can register a richer
-- override (e.g. on_click → status popup) to take priority.
--
-- See :help smart-actions for the full surface (categories, context,
-- extension points, known limitations).

-- Register the busy-slot takeover at spec-import time — not inside
-- `config` — so a user override of `config` in user/plugins/ does not
-- bypass it. The override function itself guards against smart_actions
-- not being loaded yet.
pcall(function()
	local sl = require("noethervim.statusline")
	if not sl.register_busy_override then return end
	sl.register_busy_override(function()
		local ok, status = pcall(require, "smart_actions.status")
		if not ok then return nil end
		local rec = status.current()
		if not rec then return nil end
		local palette = require("noethervim.util.palette").resolve()
		return {
			label = rec.state == "pending" and "ai…" or "ai",
			hl    = { fg = palette.purple or "#c678dd", bold = true },
		}
	end)
end)

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
