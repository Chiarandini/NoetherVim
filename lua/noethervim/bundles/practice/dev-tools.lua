-- NoetherVim bundle: Neovim Developer Tools
-- Enable with: { import = "noethervim.bundles.practice.dev-tools" }
--
-- Provides:
--   :StartupTime     — benchmark startup (averaged over 10 runs)
--   :Luapad          — interactive Lua scratchpad buffer

return {
	{
		"dstein64/vim-startuptime",
		cmd  = "StartupTime",
		init = function()
			vim.g.startuptime_tries = 10
		end,
	},
	{ -- interactive Lua scratchpad
		"rafcamlet/nvim-luapad",
		cmd = "Luapad",
		config = function()
			require("luapad").setup()
		end,
	},
}
