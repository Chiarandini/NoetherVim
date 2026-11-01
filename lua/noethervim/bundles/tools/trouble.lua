---@bundle trouble
---@desc trouble.nvim's diagnostics panel, with ]q and [q following it
---@about trouble.nvim lists diagnostics grouped by file and updated as they change. <C-w>Q
---       toggles its panel in place of core's quickfix list of diagnostics, and ]q, [q,
---       ]Q and [Q walk Trouble's items while the panel is open, the quickfix list otherwise.
---@requires none
-- NoetherVim bundle: trouble
-- Enable with: { import = "noethervim.bundles.tools.trouble" }

--- Trouble's items while its panel is open, the quickfix list otherwise.
---@param trouble_fn fun(trouble: table)
---@param qf_cmd string
local function trouble_or_qf(trouble_fn, qf_cmd)
	return function()
		local ok, trouble = pcall(require, "trouble")
		if ok and trouble.is_open() then
			trouble_fn(trouble)
		else
			local success, err = pcall(vim.cmd, qf_cmd)
			if not success and err then
				vim.notify(err:gsub("^.*:%s*", ""), vim.log.levels.WARN)
			end
		end
	end
end

return {
	{
		"folke/trouble.nvim",
		dependencies = "nvim-tree/nvim-web-devicons",
		cmd = "Trouble",
		opts = {},
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("trouble.nvim", {
			{ "<C-w>Q", "<cmd>Trouble diagnostics toggle<cr>", desc = "Trouble diagnostics panel" },
			{ "]q", trouble_or_qf(function(t) t.next({ jump = true }) end, "cnext"),
			  desc = "next quickfix/Trouble item", set = "remaps" },
			{ "[q", trouble_or_qf(function(t) t.prev({ jump = true }) end, "cprev"),
			  desc = "prev quickfix/Trouble item", set = "remaps" },
			{ "]Q", trouble_or_qf(function(t) t.last({ jump = true }) end, "clast"),
			  desc = "last quickfix/Trouble item", set = "remaps" },
			{ "[Q", trouble_or_qf(function(t) t.first({ jump = true }) end, "cfirst"),
			  desc = "first quickfix/Trouble item", set = "remaps" },
		}) } },
	},
}
