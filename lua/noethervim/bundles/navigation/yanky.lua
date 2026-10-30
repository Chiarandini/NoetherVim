---@bundle yanky
---@desc yank history you can cycle after pasting
---@about Keeps a rolling history of every yank and delete, so you can paste,
---       realise it was the wrong one, and cycle back through earlier yanks
---       instead of re-yanking or pre-tagging named registers. A fuzzy picker
---       covers the full history.
---@requires none
-- NoetherVim bundle: Yank ring
-- Enable with: { import = "noethervim.bundles.navigation.yanky" }
--
-- Keeps a rolling history of every yank/delete so you can paste, realise
-- it was the wrong one, and cycle back through earlier yanks instead of
-- needing to re-yank or pre-tag named registers.
--
-- Provides:
--   yanky.nvim         persistent yank/delete history with cycle-after-paste
--                      and a fuzzy picker over the full history.
--
-- Default keymaps:
--   y / p / P          intercepted by yanky -- behaves identically to vanilla
--                      yank/paste, plus the operation lands in the ring.
--                      Visual p keeps core's paste over the selection that
--                      keeps the register; visual P stays core's.
--   <C-p> / <C-n>      *immediately after* p / P, cycle to the previous /
--                      next entry in the yank history.
--   ]p / [p / ]P / [P  vanilla "paste-with-indent" but ring-aware.
--   SearchLeader + y   fuzzy-pick from the full yank history (whichever
--                      picker yanky discovers; Snacks is supported).
--
-- Note on <C-p> / <C-n>: vanilla Vim binds these in normal mode to
-- "previous/next line" (rarely used; j / k cover this). Yanky overrides
-- them only in normal mode, and they only fire usefully right after a
-- paste -- elsewhere they behave like before. Core binds normal <C-n> to
-- start a multi-cursor session (vim-visual-multi); with this bundle on,
-- <C-n> is yanky's, and visual <C-n> still starts one from a selection.
--
-- Storage: the ring is persisted in shada by default, so yank history
-- survives restarts. To make it session-only, override `ring.storage =
-- "memory"` in lua/user/plugins/yanky.lua.

local SearchLeader = require("noethervim.util").search_leader

return {
  {
    "gbprod/yanky.nvim",
    cmd = { "YankyRingHistory", "YankyClearHistory" },
    specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("yanky.nvim", {
      { "y", "<Plug>(YankyYank)",       mode = { "n", "x" }, desc = "yank (recorded)", set = "remaps" },
      { "p", "<Plug>(YankyPutAfter)",   desc = "paste after", set = "remaps" },
      { "P", "<Plug>(YankyPutBefore)",  desc = "paste before", set = "remaps" },
      -- Visual p keeps core's meaning, a paste over the selection that keeps
      -- the register (`P`); visual P stays core's clipboard paste.
      { "p", "<Plug>(YankyPutBefore)",  mode = "x", desc = "paste over (keep register)", set = "remaps" },
      { "<C-p>", "<Plug>(YankyPreviousEntry)", desc = "cycle to previous yank", set = "remaps" },
      { "<C-n>", "<Plug>(YankyNextEntry)",     desc = "cycle to next yank", set = "remaps" },
      { "]p", "<Plug>(YankyPutIndentAfterLinewise)",  desc = "paste below (indent)", set = "remaps" },
      { "[p", "<Plug>(YankyPutIndentBeforeLinewise)", desc = "paste above (indent)", set = "remaps" },
      { "]P", "<Plug>(YankyPutIndentAfterLinewise)",  desc = "paste below (indent)", set = "remaps" },
      { "[P", "<Plug>(YankyPutIndentBeforeLinewise)", desc = "paste above (indent)", set = "remaps" },
      { SearchLeader .. "y", "<cmd>YankyRingHistory<cr>", desc = "[y]ank history" },
    }) } },
    opts = {
      ring = {
        history_length              = 100,
        storage                     = "shada",
        sync_with_numbered_registers = true,
      },
      highlight = { on_put = true, on_yank = true, timer = 200 },
      preserve_cursor_position = { enabled = true },
    },
  },
}
