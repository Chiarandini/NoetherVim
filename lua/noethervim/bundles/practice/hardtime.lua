---@bundle hardtime
---@desc blocks repeated hjkl to build motion habits
---@about Warns on, or outright blocks, repeated hjkl and other low-value
---       motions so you reach for a real motion instead. Starts disabled; run
---       :Hardtime to switch it on.
---@requires none
-- NoetherVim bundle: Hardtime (vim motion trainer)
-- Enable with: { import = "noethervim.bundles.practice.hardtime" }
--
-- Enforces good vim motion habits by blocking or warning on repeated hjkl.
-- Mode: "hint" (warns) or "block" (prevents). Starts disabled; run :Hardtime.

return {
	{
		"m4xshen/hardtime.nvim",
		dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
		cmd    = "Hardtime",
		opts = {
			disabled_filetypes = { "qf", "netrw", "NvimTree", "lazy", "mason", "oil" },
			restriction_mode   = "hint",
			disable_mouse      = false,
		},
	},
}
