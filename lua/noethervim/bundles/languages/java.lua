---@bundle java
---@desc Java language server with proper workspace handling
---@about jdtls needs workspace management and jar paths that plain lspconfig
---       cannot supply, so it gets a dedicated client. It starts on the first
---       .java buffer. Install the server itself with :MasonInstall jdtls.
---@requires exe=java label="a JDK" why="jdtls will not start without one"
---          install="JDK 17 or newer; jdtls itself installs via Mason"
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
