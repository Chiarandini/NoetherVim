-- NoetherVim bundle: Hardtime (vim motion trainer)
-- Enable with: { import = "noethervim.bundles.hardtime" }
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
