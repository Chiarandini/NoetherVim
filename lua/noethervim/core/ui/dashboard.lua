-- NoetherVim plugin: dashboard (snacks)

-- Dashboard wordmark. The distribution shipped snacks' NEOVIM art with a
-- dash bolted on either side, so the first thing a new user saw branded
-- their install as plain Neovim -- with no evidence they had installed a
-- distribution at all.
--
-- NOETHER is noethervim-tableaux's; VIM is the tail of snacks' own art, so
-- the letterforms match by construction rather than by redrawing them.
--
-- 83 columns, which is wider than most defaults: `header` picks the narrow
-- wordmark below when the window cannot hold it, since a clipped logo reads
-- worse than a plain one.
local _wordmark = table.concat({
	"███╗   ██╗ ██████╗ ███████╗████████╗██╗  ██╗███████╗██████╗ ██╗   ██╗██╗███╗   ███╗",
	"████╗  ██║██╔═══██╗██╔════╝╚══██╔══╝██║  ██║██╔════╝██╔══██╗██║   ██║██║████╗ ████║",
	"██╔██╗ ██║██║   ██║█████╗     ██║   ███████║█████╗  ██████╔╝██║   ██║██║██╔████╔██║",
	"██║╚██╗██║██║   ██║██╔══╝     ██║   ██╔══██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██║██║╚██╔╝██║",
	"██║ ╚████║╚██████╔╝███████╗   ██║   ██║  ██║███████╗██║  ██║ ╚████╔╝ ██║██║ ╚═╝ ██║",
	"╚═╝  ╚═══╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
}, "\n")

local _wordmark_narrow = table.concat({
	"",
	"─── N O E T H E R V I M ───",
	"",
}, "\n")

--- The widest wordmark the window can hold. Snacks centres the block and
--- does not wrap it (`preset.header` is a plain string, read at render), so
--- anything wider than the window loses its right-hand letters -- on this
--- one that would leave "NOETHERV". Resolved once, when the spec loads:
--- the dashboard is a startup surface, and a terminal resized afterwards
--- has already moved past it.
local function _header()
	return vim.o.columns >= 87 and _wordmark or _wordmark_narrow
end

return {
	{
		"folke/snacks.nvim",
		opts = {
			-- `opts = { dashboard = { enabled = false } }` on snacks in
			-- lua/user/plugins/ turns it off. See :help noethervim-dashboard.
			dashboard = {
				enabled = true,
				preset = {
					header = _header(),
					keys = {
						{ icon = " ", key = "i", desc = "New File (insert)",  action = ":ene | startinsert" },
						{ icon = " ", key = "e", desc = "New File (normal)",  action = ":ene" },
						{ icon = " ", key = "f", desc = "Find File",          action = function() require("noethervim.pick").open("files") end },
						{ icon = " ", key = "o", desc = "Old Files",          action = function() require("noethervim.pick").open("recent") end },
						{ icon = " ", key = "r", desc = "Restore Session",    action = ":lua require('persistence').load({ last = true })" },
						{ icon = " ", key = "c", desc = "Config",             action = ":e $MYVIMRC" },
						{ icon = " ", key = "q", desc = "Quit",               action = ":qa" },
					},
				},
				sections = {
					{ section = "header" },
					{ section = "keys", gap = 1, padding = 1 },
					-- Registered in snacks.lua's config, once snacks is set up.
					{ section = "noether_footer", padding = 1 },
				},
			},
		},
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("snacks.nvim", {}, {
			startup = { ["dashboard.wipe-guard"] = function()
				-- Workaround for snacks.nvim #2724: the dashboard registers one handler
				-- on both BufDelete and BufWipeout that calls nvim_del_augroup_by_id.
				-- When the bufhidden=wipe dashboard buffer is replaced (e.g. selecting
				-- a file from Snacks.picker.recent()), both events fire in sequence and
				-- the second call errors with E367. We hook the User SnacksDashboardOpened
				-- event (fired after dashboard:init registers the buggy autocmd) and
				-- replace it with a pcall'd version. FileType won't work here because
				-- snacks sets `eventignore=all` while setting the buffer's filetype.
				-- Remove once PR #2725 merges.
				vim.api.nvim_create_autocmd("User", {
					pattern = "SnacksDashboardOpened",
					callback = function()
						for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
							if vim.bo[bufnr].filetype == "snacks_dashboard" then
								for _, ac in ipairs(vim.api.nvim_get_autocmds({
									event = { "BufDelete", "BufWipeout" },
									buffer = bufnr,
								})) do
									pcall(vim.api.nvim_del_autocmd, ac.id)
								end
								local augroup = vim.api.nvim_create_augroup("snacks_dashboard", { clear = false })
								vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
									buffer = bufnr,
									callback = function()
										vim.api.nvim_exec_autocmds("User", {
											pattern = "SnacksDashboardClosed",
											modeline = false,
										})
										pcall(vim.api.nvim_del_augroup_by_id, augroup)
									end,
								})
							end
						end
					end,
				})
			end },
		}) } },
	},
}
