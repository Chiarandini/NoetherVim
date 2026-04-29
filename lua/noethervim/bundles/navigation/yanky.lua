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
--   <C-p> / <C-n>      *immediately after* p / P, cycle to the previous /
--                      next entry in the yank history.
--   ]p / [p / ]P / [P  vanilla "paste-with-indent" but ring-aware.
--   SearchLeader + y   fuzzy-pick from the full yank history (whichever
--                      picker yanky discovers; Snacks is supported).
--
-- Note on <C-p> / <C-n>: vanilla Vim binds these in normal mode to
-- "previous/next line" (rarely used; j / k cover this).  Yanky overrides
-- them only in normal mode, and they only fire usefully right after a
-- paste -- elsewhere they behave like before.
--
-- Storage: the ring is persisted in shada by default, so yank history
-- survives restarts.  To make it session-only, override `ring.storage =
-- "memory"` in lua/user/plugins/yanky.lua.

local SearchLeader = require("noethervim.util").search_leader

return {
  {
    "gbprod/yanky.nvim",
    keys = {
      { "y", "<Plug>(YankyYank)",       mode = { "n", "x" }, desc = "yank (recorded)" },
      { "p", "<Plug>(YankyPutAfter)",   mode = { "n", "x" }, desc = "paste after"  },
      { "P", "<Plug>(YankyPutBefore)",  mode = { "n", "x" }, desc = "paste before" },
      { "<C-p>", "<Plug>(YankyPreviousEntry)", desc = "cycle to previous yank" },
      { "<C-n>", "<Plug>(YankyNextEntry)",     desc = "cycle to next yank" },
      { "]p", "<Plug>(YankyPutIndentAfterLinewise)",  desc = "paste below (indent)" },
      { "[p", "<Plug>(YankyPutIndentBeforeLinewise)", desc = "paste above (indent)" },
      { "]P", "<Plug>(YankyPutIndentAfterLinewise)",  desc = "paste below (indent)" },
      { "[P", "<Plug>(YankyPutIndentBeforeLinewise)", desc = "paste above (indent)" },
      { SearchLeader .. "y", "<cmd>YankyRingHistory<cr>", desc = "[y]ank history" },
    },
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
