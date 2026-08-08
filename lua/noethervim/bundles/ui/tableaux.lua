---@bundle tableaux
---@desc animated mathematical dashboard scenes
---@about Enabling it puts a scene on the dashboard straight away, picked at
---       random until you choose one with `<space>ud`. Thirty-one in all,
---       covering number-theoretic
---       processes such as the Sieve of Eratosthenes, Collatz and pi
---       convergents, dynamical systems including Conway's Game of Life and
---       the Lorenz attractor, topological objects, and contemplative
---       time-of-day scenes.
---@requires none
-- NoetherVim bundle: Tableaux
-- Enable with: { import = "noethervim.bundles.ui.tableaux" }
--
-- Provides: noethervim-tableaux -- a collection of 31 mathematical dashboard
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
--   :Dash, :DashNext, :DashPrev -- backwards-compat aliases.
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
			-- The plugin renders a tableau only once one has been chosen and
			-- persisted, so on a fresh enable it does nothing and the dashboard
			-- looks exactly as it did before -- which reads as the bundle not
			-- working rather than as waiting for a choice.
			--
			-- Enabling a bundle whose whole purpose is dashboard scenes IS the
			-- choice to have them, so seed one when no pick exists yet. Only
			-- when the file is absent or empty: a real pick, including a later
			-- decision to go back to the plain header, is never overwritten.
			local state = require("noethervim-tableaux.state")
			state.set_path(opts.state_file
				or (vim.fn.stdpath("state") .. "/user_dashboard_variant"))
			local chosen = state.read()
			if not chosen or chosen == "" then state.write("random") end

			require("noethervim-tableaux").setup(opts)
		end,
	},
}
