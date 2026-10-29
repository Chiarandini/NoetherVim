if require("noethervim.config").lsp_off("basedpyright") then return {} end

return {
	settings = {
		python = {
			analysis = {
				autoSearchPaths = true,
				diagnosticMode = 'openFilesOnly',
				useLibraryCodeForTypes = true,
			},
		},
	},
}
