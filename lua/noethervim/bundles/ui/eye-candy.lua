---@bundle eye-candy
---@desc animations and a diagnostics scrollbar
---@about Optional visual extras: a scrollbar carrying LSP diagnostic marks,
---       seasonal falling animations, and CellularAutomaton for when a
---       file deserves to be dissolved.
---@requires none
-- NoetherVim bundle: Eye Candy
-- Enable with: { import = "noethervim.bundles.ui.eye-candy" }
--
-- Provides:
--   cellular-automaton:     CellularAutomaton  (fun code animations)
--   drop.nvim:              seasonal / time-of-day falling animations
--   nvim-scrollbar:         side scrollbar with LSP diagnostics overlay
--
-- Turn drop.nvim off with { "folke/drop.nvim", enabled = false } in
-- lua/user/plugins/.

return {
	{
		"eandrju/cellular-automaton.nvim",
		cmd = "CellularAutomaton",
	},

	{
		"folke/drop.nvim",
		event = "VeryLazy",
		-- The screensaver only stops on cursor activity, and an unfocused
		-- pane (a detached tmux session above all) never produces any, so
		-- the animation runs forever and pins a core. Gate it on terminal
		-- focus. A startup entry, not config, so a user spec that overrides
		-- config keeps the gate. Under tmux this needs focus-events on.
		specs = { { "NoetherVim", optional = true, opts = { startup = {
			["eye-candy.drop-focus"] = function()
				local group = vim.api.nvim_create_augroup("noethervim_drop_focus", { clear = true })
				vim.api.nvim_create_autocmd("FocusLost", {
					group = group,
					callback = function()
						local cfg = package.loaded["drop.config"]
						if not cfg then return end
						-- disarm a pending screensaver countdown too; already
						-- armed, it would fire while unfocused
						if cfg.timer then cfg.timer:stop() end
						require("drop").hide()
					end,
				})
				vim.api.nvim_create_autocmd("FocusGained", {
					group = group,
					callback = function()
						local cfg = package.loaded["drop.config"]
						if cfg then cfg.sleep() end
					end,
				})
			end,
		} } } },
		-- Themes are computed here rather than in `config`, so `themes` from
		-- a spec of yours is merged over them instead of being replaced.
		opts = function()
			local opts = {
				max       = 40,
				interval  = 150,
				screensaver = (1000 * 60) * 8,
				filetypes = {},
				winblend  = 90,
			}
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
			return opts
		end,
		config = function(_, opts) require("drop").setup(opts) end,
	},

	{
		"petertriho/nvim-scrollbar",
		event = "VeryLazy",
		opts = {
			excluded_filetypes = {
				"cmp_docs", "cmp_menu", "noice", "prompt",
				"neo-tree", "NvimTree", "neo-tree-popup",
				"lazy", "alpha", "TelescopePrompt", "mpv",
				"snacks_dashboard",
			},
		},
	},
}
