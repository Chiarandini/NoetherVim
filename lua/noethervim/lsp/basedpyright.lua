vim.lsp.config('basedpyright', {
	settings = {
		python = {
			analysis = {
				autoSearchPaths = true,
				diagnosticMode = 'openFilesOnly',
				useLibraryCodeForTypes = true,
			},
		},
	},
})

vim.lsp.enable('basedpyright')
