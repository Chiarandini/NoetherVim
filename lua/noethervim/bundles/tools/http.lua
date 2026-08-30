---@bundle http
---@desc send HTTP, gRPC and GraphQL requests from a buffer
---@about kulala.nvim runs requests written in a .http or .rest file and shows
---       the response in the editor. Covers HTTP, gRPC, GraphQL, WebSocket
---       and streaming, using JetBrains HTTP Client syntax.
---@requires exe=curl label="curl" why="kulala sends every request through it"
---          install="preinstalled on macOS and most Linux distributions"
-- NoetherVim bundle: HTTP Client
-- Enable with: { import = "noethervim.bundles.tools.http" }
--
-- Provides kulala.nvim -- an in-editor HTTP/REST client.
--   Supports HTTP, gRPC, GraphQL, WebSocket, and streaming.
--   Compatible with JetBrains HTTP Client syntax.
--
-- Usage:
--   Create a .http or .rest file and write requests. This bundle loads kulala
--   for those filetypes but does not bind run keys by default; enable kulala's
--   own keymaps (opts.global_keymaps = true) or map its run / run_all / inspect
--   functions in user/keymaps.lua. Shipping default <localleader> keymaps is
--   tracked as a follow-up.
--
-- Example .http file:
--   GET https://httpbin.org/get
--   Accept: application/json

return {
	{
		"mistweaverco/kulala.nvim",
		ft = { "http", "rest" },
		opts = {},
	},
}
