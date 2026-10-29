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
		event  = "VeryLazy",
		opts = {},
		config = function(_, opts)
			require("comment-box").setup(opts)
			local map = require("noethervim.default").map
			map({ "n", "v" }, "<Leader>bb", "<cmd>CBalbox7<cr>", { desc = "comment box" })
			map("n",          "<Leader>bl", "<cmd>CBcline<cr>",  { desc = "comment line" })
		end,
	},
}
