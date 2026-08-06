---@bundle rust
---@desc rustaceanvim -- macro expansion, runnables, crate graph
---@requires exe=rust-analyzer label="rust-analyzer" why="every rustaceanvim feature" install="rustup component add rust-analyzer"
---@requires exe=cargo label="Cargo" why="building and running from the editor" install="https://rustup.rs/"
-- NoetherVim bundle: Rust
-- Enable with: { import = "noethervim.bundles.languages.rust" }
--
-- Provides rustaceanvim -- enhanced Rust development beyond plain rust-analyzer.
--   Macro expansion, runnables/debuggables, crate graph, hover actions,
--   structural search-replace, join lines, and more.
--
-- rustaceanvim manages its own LSP client -- no lspconfig setup needed
-- for rust-analyzer. Just ensure rust-analyzer is installed.
--
-- Override settings in user/plugins/:
--   { "mrcjkb/rustaceanvim", opts = { server = { settings = { ... } } } }

return {
	{
		"mrcjkb/rustaceanvim",
		version = "^6",
		ft = "rust",
	},
}
