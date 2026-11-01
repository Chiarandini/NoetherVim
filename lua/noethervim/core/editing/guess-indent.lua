-- NoetherVim plugin: Automatic Indent Detection
--  ╔══════════════════════════════════════════════════════════╗
--  ║                  Automatic indent detection              ║
--  ╚══════════════════════════════════════════════════════════╝
-- Auto-detects whether a file uses tabs or spaces (and what width)
-- and sets shiftwidth/tabstop/expandtab accordingly.
-- The distro defaults (tabstop=4, shiftwidth=4) still apply to new files.
--
-- Override via: { "NMAC427/guess-indent.nvim", opts = { ... } }

return {
	{
		"NMAC427/guess-indent.nvim",
		event = "BufReadPost",
		opts = {},
	},
}
