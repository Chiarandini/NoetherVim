-- NoetherVim bundle: Tableaux
-- Enable with: { import = "noethervim.bundles.tableaux" }
--
-- Provides: noethervim-tableaux — a collection of 31 mathematical dashboard
-- scenes ("tableaux") for snacks.nvim. Animated number-theoretic processes
-- (Sieve of Eratosthenes, Collatz, π convergents), live dynamical systems
-- (Conway's Game of Life, Lorenz attractor), topological objects (Königsberg
-- bridges, fundamental polygons), and contemplative scenes (time-of-day sky
-- with twinkling stars and weather overlay, daily-rotating mathematician
-- quotes, an Obsidian-vault gem).
--
-- Commands:
--   :Tableau [name]    switch (no arg → picker)
--   :TableauNext       cycle forward
--   :TableauPrev       cycle backward
--   :TableauWeather    force-refresh weather cache
--   :Dash, :DashNext, :DashPrev — backwards-compat aliases.
--
-- Default keymaps (disable with `keymaps = false`):
--   <space>ud    pick a tableau
--   <space>uD    cycle to the next tableau
--
-- User overrides via setup opts:
--   quotes  = require("user.data.math_quotes"),  -- list of { text, author }
--   vault   = { path = "~/Documents/Vault/", today_cmd = ":ObsidianToday" },
--   keymaps = false,                              -- skip default keymaps

return {
	{
		"Chiarandini/noethervim-tableaux",
		lazy     = false,   -- needs to register the SnacksDashboardOpened autocmd at startup
		priority = 900,     -- after snacks.nvim (1000), before most other UI
		opts     = {},
		config   = function(_, opts)
			require("noethervim-tableaux").setup(opts)
		end,
	},
}
