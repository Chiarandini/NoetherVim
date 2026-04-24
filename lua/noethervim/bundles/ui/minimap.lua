-- NoetherVim bundle: Minimap
-- Enable with: { import = "noethervim.bundles.ui.minimap" }
--
-- Displays a minimap sidebar with diagnostics, git signs, and search highlights.
-- Auto-enabled by default when this bundle is loaded.
--
-- Key bindings:
--   <c-w>m      -- toggle minimap globally
--   <leader>mwt -- toggle for current window
--   <leader>mbt -- toggle for current buffer

return {
	{
		---@module "neominimap.config.meta"
		"Isrothy/neominimap.nvim",
		keys = {
			{ "<c-w>m",    "<cmd>Neominimap toggle<cr>",        desc = "Toggle minimap" },
			{ "<leader>mo", "<cmd>Neominimap on<cr>",           desc = "Minimap on" },
			{ "<leader>mc", "<cmd>Neominimap off<cr>",          desc = "Minimap off" },
			{ "<leader>mf", "<cmd>Neominimap focus<cr>",        desc = "Focus minimap" },
			{ "<leader>mu", "<cmd>Neominimap unfocus<cr>",      desc = "Unfocus minimap" },
			{ "<leader>ms", "<cmd>Neominimap toggleFocus<cr>",  desc = "Toggle minimap focus" },
			{ "<leader>mwt", "<cmd>Neominimap winToggle<cr>",   desc = "Toggle minimap (window)" },
			{ "<leader>mwr", "<cmd>Neominimap winRefresh<cr>",  desc = "Refresh minimap (window)" },
			{ "<leader>mwo", "<cmd>Neominimap winOn<cr>",       desc = "Minimap on (window)" },
			{ "<leader>mwc", "<cmd>Neominimap winOff<cr>",      desc = "Minimap off (window)" },
			{ "<leader>mbt", "<cmd>Neominimap bufToggle<cr>",   desc = "Toggle minimap (buffer)" },
			{ "<leader>mbr", "<cmd>Neominimap bufRefresh<cr>",  desc = "Refresh minimap (buffer)" },
			{ "<leader>mbo", "<cmd>Neominimap bufOn<cr>",       desc = "Minimap on (buffer)" },
			{ "<leader>mbc", "<cmd>Neominimap bufOff<cr>",      desc = "Minimap off (buffer)" },
		},
		init = function()
			vim.g.neominimap = { auto_enable = true }
		end,
		config = function()
			require("neominimap").setup({
				auto_enable          = true,
				log_level            = vim.log.levels.OFF,
				notification_level   = vim.log.levels.INFO,
				log_path             = vim.fn.stdpath("data") .. "/neominimap.log",
				exclude_filetypes    = { "help", "tex" },
				exclude_buftypes     = { "nofile", "nowrite", "quickfix", "terminal", "prompt" },
				buf_filter           = function() return true end,
				win_filter           = function() return true end,
				max_minimap_height   = nil,
				minimap_width        = 20,
				x_multiplier         = 4,
				y_multiplier         = 1,
				delay                = 200,
				sync_cursor          = true,
				click                = { enabled = true, auto_switch_focus = true },
				diagnostic = {
					enabled  = true,
					severity = vim.diagnostic.severity.WARN,
					mode     = "line",
					priority = { ERROR = 100, WARN = 90, INFO = 80, HINT = 70 },
				},
				git        = { enabled = true, mode = "sign", priority = 6 },
				search     = { enabled = true, mode = "line", priority = 20 },
				treesitter = { enabled = true, priority = 200 },
				margin     = { right = 0, top = 0, bottom = 0 },
				fold       = { enabled = true },
				z_index    = 1,
				window_border = "single",
				winopt = {},
				bufopt = {},
			})
		end,
	},
}
