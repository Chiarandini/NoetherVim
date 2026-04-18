-- NoetherVim bundle: Eye Candy
-- Enable with: { import = "noethervim.bundles.ui.eye-candy" }
--
-- Provides:
--   cellular-automaton:     CellularAutomaton  (fun code animations)
--   drop.nvim:              seasonal / time-of-day falling animations
--   nvim-scrollbar:         side scrollbar with LSP diagnostics overlay
--   block.nvim:             :Block / :BlockOn / :BlockOff  (code block visualizer)
--
-- Disable drop.nvim by setting  drop = false  in lua/user/config.lua.

return {
	{
		"eandrju/cellular-automaton.nvim",
		cmd = "CellularAutomaton",
	},

	{
		"folke/drop.nvim",
		event = "VeryLazy",
		cond = function()
			local ok, cfg = pcall(require, "user.config")
			return not (ok and type(cfg) == "table" and cfg.drop == false)
		end,
		opts = {
			max       = 40,
			interval  = 150,
			screensaver = (1000 * 60) * 8,
			filetypes = {},
			winblend  = 90,
		},
		config = function(_, opts)
			local curTime = tonumber(os.date("%H"))
			if curTime >= 21 or curTime <= 6 then
				opts.themes = {theme = "stars"}
			else
				opts.themes = {
					{ theme = "new_year",            month = 1,  day = 1  },
					{ theme = "valentines_day",       month = 2,  day = 14 },
					{ theme = "st_patricks_day",      month = 3,  day = 17 },
					{ theme = "easter",               holiday = "easter"   },
					{ theme = "april_fools",          month = 4,  day = 1  },
					{ theme = "us_independence_day",  month = 7,  day = 4  },
					{ theme = "halloween",            month = 10, day = 31 },
					{ theme = "us_thanksgiving",      holiday = "us_thanksgiving" },
					{ theme = "xmas",    from = { month = 12, day = 20 }, to = { month = 12, day = 25 } },
					{ theme = "leaves",  from = { month = 9,  day = 22 }, to = { month = 11, day = 30 } },
					{ theme = "snow",    from = { month = 12, day = 21 }, to = { month = 3,  day = 19 } },
					{ theme = "spring",  from = { month = 3,  day = 20 }, to = { month = 6,  day = 20 } },
					{ theme = "summer",  from = { month = 6,  day = 21 }, to = { month = 9,  day = 21 } },
				}
			end
			require("drop").setup(opts)
		end,
	},

	{
		"petertriho/nvim-scrollbar",
		event = "VeryLazy",
		opts = {
			excluded_filetypes = {
				"cmp_docs", "cmp_menu", "noice", "prompt",
				"neo-tree", "NvimTree", "neo-tree-popup",
				"lazy", "alpha", "TelescopePrompt", "mpv",
			},
		},
	},

	{
		"HampusHauffman/block.nvim",
		cmd = { "Block", "BlockOn", "BlockOff" },
		keys = {
			{ "[oB", "<cmd>BlockOn<cr>",  desc = "block on" },
			{ "]oB", "<cmd>BlockOff<cr>", desc = "block off" },
		},
		config = true,
	},
}
