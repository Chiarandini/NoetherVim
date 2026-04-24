-- NoetherVim bundle: Java
-- Enable with: { import = "noethervim.bundles.languages.java" }
--
-- Provides nvim-jdtls -- proper Java LSP support.
-- Java's language server (jdtls) requires special initialization that
-- plain lspconfig cannot handle (workspace management, jar paths, etc.).
--
-- Requirements:
--   Install jdtls via Mason (:MasonInstall jdtls) or manually.
--
-- The plugin auto-starts jdtls when you open a .java file.
-- Override settings in user/plugins/:
--   { "mfussenegger/nvim-jdtls", opts = { settings = { java = { ... } } } }

return {
	{
		"mfussenegger/nvim-jdtls",
		ft = "java",
	},
}
