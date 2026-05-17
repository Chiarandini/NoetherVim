return {
	'BirdeeHub/argmark',
	event = "BufReadPost",
	config = function()
		require("argmark").setup {
			keys = {
				edit = "<space>ae",
				rm = "<leader>ax",
				go = "<leader>a<leader>",
				add = "<leader>aa",
				copy = "<leader>ac",
				clear = "<leader>aX",
				add_windows = "<leader>aA",
			},
			edit_opts = {
				keys = {
					cycle_right = "]a",
					cycle_left = "[a",
					go = "<CR>",
					quit = "Q", -- save and quit
					exit = "q", -- exit
					-- :write or :w also saves, but doesn't quit
				}
			}
		}
	end
}
