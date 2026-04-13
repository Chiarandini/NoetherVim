vim.lsp.config('lua_ls', {
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
})

vim.lsp.enable('lua_ls')
