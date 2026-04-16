-- NoetherVim plugin: Which-Key
-- Popup that shows available keybindings after a prefix key.
-- Also integrates marks, registers, and spelling suggestions.

--- Open a Snacks picker populated with the current which-key items.
--- Groups recurse into a sub-picker; leaf mappings are executed.
local function wk_picker(data)
	local View = require("which-key.view")

	local function pick(items, node)
		local title = (node.desc and node.desc ~= "") and node.desc or node.keys or "Which Key"

		require("snacks").picker({
			title = title,
			items = (function()
				local ret = {}
				for _, item in ipairs(items) do
					ret[#ret + 1] = {
						text = item.raw_key .. " " .. (item.desc or ""),
						formatted_key = item.key,
						desc = item.desc or "",
						icon = item.icon or "",
						icon_hl = item.icon_hl,
						is_group = item.group or false,
						node = item.node,
					}
				end
				return ret
			end)(),

			format = function(item)
				local ret = {}
				if item.icon ~= "" then
					ret[#ret + 1] = { item.icon .. " ", item.icon_hl or "WhichKeyIcon" }
				end
				ret[#ret + 1] = { string.format("%-8s", item.formatted_key), "WhichKey" }
				ret[#ret + 1] = { item.desc, item.is_group and "WhichKeyGroup" or "WhichKeyDesc" }
				return ret
			end,

			confirm = function(picker, item)
				picker:close()
				if not item then return end
				if item.is_group and item.node:is_group() then
					local sub = View.get_items_for_node(item.node)
					if #sub > 0 then
						pick(sub, item.node)
						return
					end
				end
				-- leaf: execute
				if item.node.action then
					item.node.action()
				else
					local feed = vim.api.nvim_replace_termcodes(item.node.keys, true, true, true)
					vim.api.nvim_feedkeys(feed, "mit", false)
				end
			end,
		})
	end

	pick(data.items, data.node)
end

return {
	{
		"Chiarandini/which-key.nvim",
		branch = "feat/picker-integration",
		event = "VeryLazy",
		dependencies = {
			'echasnovski/mini.icons'
		},
		opts = {
			preset = "modern",
			delay = function(ctx)
				return ctx.plugin and 0 or 1500
			end,
			keys = {
				picker = "<C-f>",
			},
			picker = wk_picker,
			plugins = {
				marks = true,
				registers = true,
				spelling = {
					enabled = true,
					suggestions = 20,
				},
			},
			icons = {
				group = "",
			},
			win = {
				title = true,
				title_pos = "center",
				padding = {1, 2},
				zindex = 1000,
			},
		},
		config = function(_, opts)
			local nv = require("noethervim.util")
			local icons = nv.icons
			local SearchLeader = nv.search_leader
			vim.o.timeout = true
			vim.o.timeoutlen = 1500
			local wk = require("which-key")
			wk.setup(opts)
			wk.add({
				{
					mode = { "n", "v" },
					{"[" , icon = {icon = icons.toggle_on, color = "yellow"}, group = "toggleOn" },
					{"]" , icon = {icon = icons.toggle_off, color = "yellow"}, group= "toggleOff" },
					{"[o" , icon = {icon = icons.options_on, color = "yellow"}, group= "Options (on)" },
					{"]o" , icon = {icon = icons.options_off, color = "yellow"}, group= "Options (off)" },
					{SearchLeader , icon = {icon = icons.search, color = "yellow"}, group= "Search" },
					{SearchLeader .. "g" , icon = {icon = icons.grep, color = "orange"}, group= "Grep" },
					{SearchLeader .. "G" , icon = {icon = icons.git, color = "orange"}, group= "Git" },
					{SearchLeader .. "h" , icon = {icon = icons.fish, color = "blue"}, group= "Harpoon" },
					{SearchLeader .. "f" , icon = {icon = icons.find, color = "azure"}, group= "Find" },
					{SearchLeader .. "c" , icon = {icon = icons.config, color = "yellow"}, group= "Config" },
					{SearchLeader .. "cn" , icon = {icon = icons.Function, color = "yellow"}, group= "NoetherVim Config" },
					{SearchLeader .. "d" , icon = {icon = icons.diagnostics, color = "red"}, group= "Diagnostics" },
					{SearchLeader .. "e" , icon = {icon = icons.vim, color = "green"}, group= "Editor Files" },
					{SearchLeader .. "l" , icon = {icon = icons.nvim_lsp, color = "azure"}, group= "LSP" },
					{SearchLeader .. "w" , icon = {icon = icons.wiki, color = "blue"}, group= "Wiki" },
					{SearchLeader .. "s" , icon = {icon = icons.session, color = "purple"}, group= "Session" },
					{SearchLeader .. "q" , icon = {icon = icons.wrench, color = "blue"}, group= "quickfix" },
					{SearchLeader .. "t" , icon = {icon = icons.toc, color = "blue"}, group= "table of content" },
					{SearchLeader .. "r" , icon = {icon = icons.pencil, color = "blue"}, group= "resume" },
					{SearchLeader .. "D" , icon = {icon = icons.debug, color = "red"}, group= "Debug" },
					{SearchLeader .. "fd" , icon = {icon = icons.documents, color = "blue"}, group= "[f]ind [d]ocuments" },
					{"g",  icon = icons.plus, group = "lsp/gcc/other" },
					{"<c-w>",  icon = icons.window, group = "window" },
					{"<c-w>[",  icon = icons.window, group = "open window.." },
					{"<c-w>]",  icon = icons.window, group = "close window.." },
					{"<c-w>l",  icon = icons.lazy, group = "Lazy" },
					{"<c-w>s",  icon = {icon = icons.plus, color = "red"}, group = "Statusline" },
					{"<leader>",  icon = {icon = icons.action, color = "blue"}, group = "action" },
					{SearchLeader .. "o",  icon = {icon = icons.landplot, color = "blue"}, group = "Obsidian" },
					{"<leader>o",  icon = {icon = icons.landplot, color = "blue"}, group = "Obsidian" },
					{"<leader>m",  icon = {icon = icons.map, color = "blue"}, group = "minimap" },
					{"<leader>b",  icon = {icon = icons.box, color = "blue"}, group = "box" },
					{"<leader>f",  icon = {icon = icons.format, color = "red"}, group = "format" },
					{"<leader>B",  icon = {icon = icons.tab, color = "azure"}, group = "Buffer" },
					{"<leader>r",  icon = {icon = icons.refactor, color = "yellow"}, group = "refactor" },
					{"<leader>R",  icon = {icon = icons.run, color = "yellow"}, group = "Run/REPL" },
					{"<leader>ha", icon = {icon = icons.fish, color = "blue"},  group = "harpoon add" },
					{"[oH",        icon = {icon = icons.options_on, color = "yellow"},  desc = "show deleted hunks (gitsigns)" },
					{"]oH",        icon = {icon = icons.options_off, color = "yellow"}, desc = "hide deleted hunks (gitsigns)" },
					{"[og",        icon = {icon = icons.options_on, color = "yellow"},  desc = "git blame ON (gitsigns)" },
					{"]og",        icon = {icon = icons.options_off, color = "yellow"}, desc = "git blame OFF (gitsigns)" },
					{"gPf",        icon = icons.plus, desc = "peek function def" },
					{"gPC",        icon = icons.plus, desc = "peek class def" },
					{"[oG",        icon = {icon = icons.options_on,  color = "yellow"}, desc = "deadcolumn ON (Guide)" },
					{"]oG",        icon = {icon = icons.options_off, color = "yellow"}, desc = "deadcolumn OFF (Guide)" },
					{"[oD",        icon = {icon = icons.options_on,  color = "yellow"}, desc = "tidy ON (remove dirty whitespace)" },
					{"]oD",        icon = {icon = icons.options_off, color = "yellow"}, desc = "tidy OFF" },
					{"<leader>z",  icon = {icon = icons.zenMode, color = "yellow"}, group = "ZenMode" },
					{"<leader>h",  icon = {icon = icons.git, color = "yellow"}, group = "hunk (gitsigns)" },
					{"<leader>d",  icon = {icon = icons.debug, color = "red"}, group = "Debug" },
				},
			})
		end,
	},
}
