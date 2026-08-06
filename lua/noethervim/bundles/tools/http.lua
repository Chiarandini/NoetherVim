---@bundle http
---@desc kulala.nvim HTTP/REST/gRPC/GraphQL client
---@requires exe=curl label="curl" why="kulala sends every request through it" install="preinstalled on macOS and most Linux distributions"
-- NoetherVim bundle: HTTP Client
-- Enable with: { import = "noethervim.bundles.tools.http" }
--
-- Provides kulala.nvim -- an in-editor HTTP/REST client.
--   Supports HTTP, gRPC, GraphQL, WebSocket, and streaming.
--   Compatible with JetBrains HTTP Client syntax.
--
-- Usage:
--   Create a .http or .rest file, write requests, then:
--     <localleader>r    run request under cursor
--     <localleader>a    run all requests in file
--     <localleader>i    inspect current request
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
