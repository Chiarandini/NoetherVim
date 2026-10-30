---@bundle editing-extras
---@desc decorative comment boxes
---@about comment-box.nvim draws decorative ASCII boxes and dividers around
---       comments.
---@requires none
-- NoetherVim bundle: Editing Extras
-- Enable with: { import = "noethervim.bundles.navigation.editing-extras" }
--
-- Provides:
--   comment-box.nvim: decorative ASCII comment boxes
--     <leader>bb      left-aligned fixed-size box
--     <leader>bl      centered line separator

return {

	-- ── Comment Box ───────────────────────────────────────────────────────────
	{
		"LudoPinelli/comment-box.nvim",
		cmd  = { "CBalbox", "CBcline" },
		opts = {},
		specs = { { "which-key.nvim", optional = true, opts = require("noethervim.util").labels({ { "<leader>b", icon = { icon = require("noethervim.util").icons.box, color = "blue" }, group = "box" } }) }, { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("comment-box.nvim", {
			{ "<Leader>bb", "<cmd>CBalbox7<cr>", mode = { "n", "x" }, desc = "comment box" },
			{ "<Leader>bl", "<cmd>CBcline<cr>", desc = "comment line" },
		}) } },
		config = function(_, opts)
			require("comment-box").setup(opts)
		end,
	},
}
