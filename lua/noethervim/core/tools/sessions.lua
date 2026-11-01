-- NoetherVim plugin: Session Persistence
-- Auto-saves session on exit (per CWD) and restores the exact last state.
-- Used by the dashboard "r" key: require('persistence').load({ last = true })
return {
	"folke/persistence.nvim",
	event = "BufReadPre",
	opts = {},
}
