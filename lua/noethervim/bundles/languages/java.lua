---@bundle java
---@desc Java language server with proper workspace handling
---@about jdtls needs workspace management and jar paths that plain lspconfig
---       cannot supply, so it gets a dedicated client. It starts on the first
---       .java buffer. Install the server itself with :MasonInstall jdtls.
---       With the test bundle also enabled, registers the JUnit adapter.
---@requires exe=java label="a JDK" why="jdtls will not start without one"
---          install="JDK 17 or newer; jdtls itself installs via Mason"
---@requires note="Maven or Gradle"
---          why="neotest-java builds and runs through the project's own tool,
---               when the test bundle is also enabled"
---          install="whichever your project already uses" optional=true
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

	-- ── Java test adapter ─────────────────────────────────────────────────
	-- `optional = true` means lazy.nvim drops this fragment unless neotest is
	-- required by something else, i.e. unless tools/test.lua is enabled.
	--
	-- Built in an `opts` function so the `require` runs after the adapter
	-- plugin loads; see tools/test.lua for why `adapters` merges as it does.
	--
	-- neotest-java reads the classpath from the running jdtls client, which
	-- is what nvim-jdtls above starts, and detects Maven or Gradle from the
	-- project itself.
	{
		"nvim-neotest/neotest",
		optional = true,
		dependencies = { "rcasia/neotest-java" },
		opts = function(_, opts)
			opts.adapters = opts.adapters or {}
			table.insert(opts.adapters, require("neotest-java")({}))
		end,
	},
}
