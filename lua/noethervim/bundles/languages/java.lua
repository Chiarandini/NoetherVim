---@bundle java
---@desc Java language server with proper workspace handling
---@about jdtls needs workspace management and jar paths that plain lspconfig
---       cannot supply, so it gets a dedicated client, started per buffer with
---       a workspace directory of its own. With the debug bundle also enabled
---       it loads the Java debug and test jars into the server, which is what
---       makes breakpoints and the JUnit adapter work.
---@requires exe=java label="a JDK 21 or newer"
---          why="jdtls itself runs on 21; the project it indexes may target older"
---          install="https://adoptium.net/"
---@requires note="Maven or Gradle"
---          why="neotest-java builds and runs through the project's own tool,
---               when the test bundle is also enabled"
---          install="whichever your project already uses" optional=true
-- NoetherVim bundle: Java
-- Enable with: { import = "noethervim.bundles.languages.java" }
--
-- Provides nvim-jdtls: Java LSP support beyond what plain lspconfig can do.
-- jdtls needs a per-project workspace directory and, for debugging, extra jars
-- loaded into the server itself, neither of which `vim.lsp.enable` expresses.
--
-- nvim-jdtls does NOT start the server on its own; it exposes
-- `require("jdtls").start_or_attach(config)` and expects the config to call it
-- per Java buffer. That call lives in this bundle's `config` below.
--
-- Override settings in user/plugins/:
--   { "mfussenegger/nvim-jdtls", opts = { settings = { java = { ... } } } }

--- Build the jdtls client config for the current buffer.
---
--- The workspace directory is per project and must not be shared: jdtls stores
--- an index there, and pointing two projects at one directory corrupts it.
---@return table
local function jdtls_config()
	local mason = vim.fs.joinpath(vim.fn.stdpath("data"), "mason")
	local root = vim.fs.root(0, { "pom.xml", "build.gradle", "build.gradle.kts", "mvnw", "gradlew", ".git" })
		or vim.fn.getcwd()

	-- The debug and test jars are loaded by the server, not by nvim-dap, so
	-- they are passed through `init_options.bundles`. `vim.fn.glob` returns an
	-- empty string when nothing matches, which would otherwise put a bogus ""
	-- entry in the list and make jdtls reject the whole set.
	local bundles = {}
	for _, pattern in ipairs({
		vim.fs.joinpath(mason, "packages", "java-debug-adapter", "extension", "server",
			"com.microsoft.java.debug.plugin-*.jar"),
		vim.fs.joinpath(mason, "packages", "java-test", "extension", "server", "*.jar"),
	}) do
		for _, jar in ipairs(vim.fn.glob(pattern, true, true)) do
			if jar ~= "" then bundles[#bundles + 1] = jar end
		end
	end

	return {
		cmd = { vim.fs.joinpath(mason, "bin", "jdtls"), "-data",
			vim.fs.joinpath(vim.fn.stdpath("cache"), "jdtls", vim.fn.fnamemodify(root, ":p:h:t")) },
		root_dir = root,
		init_options = { bundles = bundles },
	}
end

return {
	{
		"mfussenegger/nvim-jdtls",
		ft = "java",
		config = function(_, opts)
			local function start(bufnr)
				if vim.bo[bufnr].filetype ~= "java" then return end
				if vim.fn.executable("java") ~= 1 then return end
				local config = vim.tbl_deep_extend("force", jdtls_config(), opts or {})

				-- nvim-jdtls registers no DAP configurations by itself, the same
				-- way it starts no client by itself. Without these two calls the
				-- debug jars are loaded into the server and `dap.configurations
				-- .java` is still empty, so <F5> has nothing to offer. Resolving
				-- the main classes is an LSP request, so it waits for attach.
				config.on_attach = function()
					if not pcall(require, "dap") then return end
					pcall(function()
						require("jdtls").setup_dap({ hotcodereplace = "auto" })
						require("jdtls.dap").setup_dap_main_class_configs()
					end)
				end

				require("jdtls").start_or_attach(config)
			end

			-- Both halves are needed. `ft = "java"` means lazy loads this on the
			-- first Java buffer and re-fires FileType for it, but an autocmd
			-- registered here would still miss that buffer on some paths, so
			-- start it directly as well; the autocmd covers every later one.
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("noethervim_jdtls", { clear = true }),
				pattern = "java",
				callback = function(ev) start(ev.buf) end,
			})
			start(vim.api.nvim_get_current_buf())
		end,
	},

	-- jdtls is a Mason package like any other server. mason-lspconfig installs
	-- it; nothing enables it through `vim.lsp.enable`, because nvim-jdtls
	-- starts the client itself with the config above.
	{ "neovim/nvim-lspconfig",
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			vim.list_extend(opts.ensure_installed, { "jdtls" })
		end,
	},

	{ "nvim-treesitter/nvim-treesitter",
		opts = { ensure_installed = { "java" } },
	},

	{ "stevearc/conform.nvim",
		opts = function(_, opts)
			opts.formatters_by_ft = opts.formatters_by_ft or {}
			opts.formatters_by_ft.java = { "google-java-format" }
			opts.mason_install = opts.mason_install or {}
			table.insert(opts.mason_install, "google-java-format")
		end,
	},

	-- ── Java debug adapter ────────────────────────────────────────────────
	-- `optional = true` gates this on tools/debug.lua, like every other
	-- language bundle.
	--
	-- Java is the one language here whose debug adapter is not a separate
	-- process: java-debug-adapter is a jar loaded into jdtls, which then serves
	-- DAP over the language server. That is why there is no `dap.adapters.java`
	-- to define; asking Mason for the jars is what makes `nvim-jdtls` register
	-- the adapter when it starts. `java-test` carries the JUnit half that
	-- neotest-java drives.
	{
		"mfussenegger/nvim-dap",
		optional = true,
		opts = function(_, opts)
			opts.mason_install = opts.mason_install or {}
			vim.list_extend(opts.mason_install, { "java-debug-adapter", "java-test" })
		end,
	},

	-- ── Java test adapter ─────────────────────────────────────────────────
	-- `optional = true` means lazy.nvim drops this fragment unless neotest is
	-- required by something else, i.e. unless tools/test.lua is enabled.
	--
	-- neotest-java reads the classpath from the running jdtls client, which is
	-- what the config above starts, and detects Maven or Gradle from the
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
