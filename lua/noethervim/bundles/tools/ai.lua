-- NoetherVim bundle: AI (CodeCompanion)
-- Enable with: { import = "noethervim.bundles.tools.ai" }
--
-- Provides CodeCompanion.nvim for AI-assisted coding. Supports multiple
-- providers: Anthropic (default), OpenAI, Gemini, Ollama, and more.
--
-- API key resolution order:
--   1. lua/secrets.lua  (local override, gitignored)
--   2. Environment variable ($ANTHROPIC_API_KEY, $OPENAI_API_KEY, etc.)
--
-- To switch provider, override in user/plugins/:
--   { "olimorris/codecompanion.nvim", opts = {
--       adapter = "openai",   -- or "gemini", "ollama", "copilot", etc.
--   } }

return {
	{
		"olimorris/codecompanion.nvim",
		keys = {
			{ "<leader>ac", "<cmd>CodeCompanionChat<cr>", desc = "[a]i [c]hat" },
		},
		cmd = "CodeCompanion",
		opts = {
			-- Default adapter; override via user/plugins/ to switch provider.
			adapter = "anthropic",
			strategies = {
				chat   = { adapter = "anthropic" },
				inline = { adapter = "anthropic" },
			},
		},
		config = function(_, opts)
			local ok, secrets = pcall(require, "secrets")
			local adapter = opts.adapter or "anthropic"

			-- Map adapter names to their environment variable and secrets key.
			local api_key_map = {
				anthropic = { env = "ANTHROPIC_API_KEY", key = "anthropic" },
				openai    = { env = "OPENAI_API_KEY",    key = "openai" },
				gemini    = { env = "GEMINI_API_KEY",    key = "gemini" },
				deepseek  = { env = "DEEPSEEK_API_KEY",  key = "deepseek" },
				mistral   = { env = "MISTRAL_API_KEY",   key = "mistral" },
				xai       = { env = "XAI_API_KEY",       key = "xai" },
			}

			-- Apply the adapter choice to strategies.
			opts.strategies.chat.adapter = adapter
			opts.strategies.inline.adapter = adapter

			-- Resolve API key for adapters that need one.
			local key_info = api_key_map[adapter]
			if key_info then
				local api_key = (ok and secrets[key_info.key] and secrets[key_info.key].api_key)
					or os.getenv(key_info.env)
				if not api_key then
					vim.notify(
						"AI bundle: set " .. key_info.env .. " or add " .. key_info.key .. " to lua/secrets.lua",
						vim.log.levels.WARN
					)
					return
				end
				opts.adapters = opts.adapters or {}
				opts.adapters[adapter] = function()
					return require("codecompanion.adapters").extend(adapter, {
						env = { api_key = api_key },
					})
				end
			end
			-- Adapters without API keys (ollama, copilot, etc.) work out of the box.

			require("codecompanion").setup(opts)
			vim.cmd("cabbrev cc CodeCompanion")
		end,
	},
}
