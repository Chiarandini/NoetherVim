-- NoetherVim bundle: Translation
-- Enable with: { import = "noethervim.bundles.translation" }
--
-- Provides pantran.nvim for in-editor text translation.
-- Default engine: Google Translate.
--   <c-w><m-t>  — open translation popup
--   :Pantran    — open translation popup

return {
	{
		"potamides/pantran.nvim",
		cmd  = "Pantran",
		keys = {
			{ "<c-w><m-t>", "<cmd>Pantran<cr>", desc = "Translate" },
		},
		opts = {
			default_engine = "google",
			engines = {
				yandex = {
					default_source = "auto",
					default_target = "en",
				},
			},
			controls = {
				mappings = {
					edit   = { n = { ["j"] = "gj", ["k"] = "gk" }, i = {} },
					select = { n = {} },
				},
			},
		},
	},
}
