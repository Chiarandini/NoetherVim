if require("noethervim.config").lsp_off("lua_ls") then return {} end

return {
	settings = {
		Lua = {
			completion = {
				callSnippet = 'Both',
			},
			diagnostics = {
				disable = { 'incomplete-signature-doc', 'missing-fields' },
				globals = { 'vim' },
			},
			hint = {
				enable = false,
				arrayIndex = 'Disable',
			},
			telemetry = { enable = false },
			workspace = {
				checkThirdParty = false,
			},
		},
	},
}
