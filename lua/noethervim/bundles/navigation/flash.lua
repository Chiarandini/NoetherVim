-- NoetherVim bundle: Flash (enhanced motion)
-- Enable with: { import = "noethervim.bundles.navigation.flash" }
--
-- Augments /? search and f/t/F/T motions with labeled jump targets.
--   S          — jump to label  (normal mode)
--   r          — remote flash   (operator-pending)
--   R          — treesitter search  (operator-pending, visual)
--   <c-s>      — toggle flash in command mode

return {
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		opts  = {},
		keys  = {
			{ "S",    function() require("flash").jump()              end, mode = { "n" },          desc = "Flash jump" },
			{ "r",    function() require("flash").remote()            end, mode = "o",               desc = "Flash remote" },
			{ "R",    function() require("flash").treesitter_search() end, mode = { "o", "x" },      desc = "Flash treesitter search" },
			{ "<c-s>", function() require("flash").toggle()           end, mode = { "c" },           desc = "Toggle flash" },
		},
	},
}
