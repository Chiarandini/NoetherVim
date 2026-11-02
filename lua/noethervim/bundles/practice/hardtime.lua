---@bundle hardtime
---@desc blocks repeated hjkl to build motion habits
---@about Warns on, or outright blocks, repeated hjkl and other low-value
---       motions so you reach for a real motion instead. Starts switched off;
---       :Hardtime enable (or toggle) switches it on.
---@requires none
-- NoetherVim bundle: Hardtime (vim motion trainer)
-- Enable with: { import = "noethervim.bundles.practice.hardtime" }
--
-- Enforces good vim motion habits by blocking or warning on repeated hjkl.
-- Mode: "hint" (warns) or "block" (prevents). Starts switched off;
-- :Hardtime enable (or toggle) switches it on.

return {
	{
		"m4xshen/hardtime.nvim",
		dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
		-- hardtime.nvim defines :Hardtime from a 500 ms timer in its setup, so
		-- a `cmd` trigger would run the command before it exists. Loaded once
		-- startup is over instead, switched off until asked.
		event = "VeryLazy",
		opts = {
			enabled            = false,
			disabled_filetypes = { "qf", "netrw", "NvimTree", "lazy", "mason", "oil" },
			restriction_mode   = "hint",
			disable_mouse      = false,
		},
	},
}
