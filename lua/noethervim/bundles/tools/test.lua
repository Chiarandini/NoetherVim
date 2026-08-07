---@bundle test
---@desc run tests and see results against the code
---@about The neotest framework, with results shown beside the code they
---       cover. The runner itself is language-agnostic; each language
---       bundle registers its own adapter when this bundle is also enabled.
---@requires none
-- NoetherVim bundle: Test Runner
-- Enable with: { import = "noethervim.bundles.tools.test" }
--
-- Provides neotest -- a test runner framework.
--
-- Adapters live with their language, and activate only when both that
-- bundle and this one are enabled (lazy.nvim `optional = true`):
--   • languages/python.lua:  pytest / unittest, via neotest-python
--   • languages/go.lua:      go test, via neotest-golang
--   • languages/rust.lua:    cargo test, via rustaceanvim's own adapter
--   • languages/java.lua:    JUnit, via neotest-java
--   • languages/web-dev.lua: Jest and Vitest
--
-- Enabling this bundle on its own gives you the UI and no adapters, so
-- `:Neotest run` finds nothing. That is the same arrangement debug.lua
-- uses, and for the same reason: an adapter is only useful to someone who
-- already opted into the language.
--
-- To add an adapter for a language with no bundle, append to `adapters` from
-- lua/user/plugins/, using the function form of `opts` so the `require` runs
-- at load time rather than while specs are collected:
--
--   { "nvim-neotest/neotest",
--     dependencies = { "some/neotest-adapter" },
--     opts = function(_, opts)
--       table.insert(opts.adapters, require("neotest-adapter")({}))
--     end }

return {
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		cmd    = { "Neotest" },

		-- ── Why <Leader>t ─────────────────────────────────────────────────
		-- Sibling of <Leader>d, the debug namespace. Test and debug are the
		-- two "run my code" bundles, and neotest's dap strategy joins them at
		-- <Leader>td, so adjacent prefixes are the honest shape. <Leader>t
		-- and <Leader>T were both free.
		--
		-- No function keys. The debug bundle owns that tier (F5/F10/F11 and
		-- friends) for its stepping loop, where a key is pressed dozens of
		-- times per session. Testing is run-look-fix, not a loop, and two
		-- bundles reaching for the same six keys is a clash a user cannot
		-- resolve per bundle.
		--
		-- Nothing under SearchLeader. That namespace is for pickers, and
		-- neotest has none: its surfaces are a summary tree and an output
		-- panel, neither of which is a searchable list.
		keys = {
			{ "<leader>tt", function() require("neotest").run.run() end,                        desc = "run nearest [t]est" },
			{ "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end,      desc = "run test [f]ile" },
			{ "<leader>ta", function() require("neotest").run.run(vim.uv.cwd()) end,            desc = "run [a]ll tests" },
			{ "<leader>tl", function() require("neotest").run.run_last() end,                   desc = "run [l]ast test" },
			{ "<leader>tq", function() require("neotest").run.stop() end,                       desc = "[q]uit running test" },
			{ "<leader>ts", function() require("neotest").summary.toggle() end,                 desc = "toggle [s]ummary" },
			{ "<leader>to", function() require("neotest").output.open({ enter = true }) end,    desc = "show test [o]utput" },
			{ "<leader>tO", function() require("neotest").output_panel.toggle() end,            desc = "toggle [O]utput panel" },
			{ "<leader>tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "toggle [w]atch on file" },
		},

		-- `adapters` is built by other bundles, so it needs both halves of
		-- lazy.nvim's list handling:
		--
		-- `opts_extend` makes the merge additive. Without it, `adapters = {}`
		-- below REPLACES whatever the language bundles registered, but only
		-- when this fragment merges after theirs -- and the stock init.lua
		-- imports languages/ before tools/, so that is the normal order.
		-- The symptom is an empty adapter list with nothing to point at.
		--
		-- Each contributor still has to use the function form of `opts`,
		-- because an adapter is an object the adapter plugin constructs. A
		-- table value would be evaluated while specs are still being
		-- collected, before that plugin is on the runtimepath.
		opts_extend = { "adapters" },
		opts = { adapters = {} },
	},

	-- ── Debug the test under the cursor ───────────────────────────────────
	-- Gated on nvim-dap the same way the language adapters are, so the key
	-- only exists when tools/debug.lua is also enabled. Bound here rather
	-- than in the debug bundle because it is a test action that happens to
	-- use a debug strategy, and it sits with its siblings under <Leader>t.
	{
		"mfussenegger/nvim-dap",
		optional = true,
		keys = {
			{ "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end,
			  desc = "[d]ebug nearest test" },
		},
	},
}
