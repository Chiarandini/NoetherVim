-- Replace NoetherVim's tabline with a bufferline.
--
-- NoetherVim defaults to a tab-based tabline because tabs and buffers
-- serve different purposes in Vim's model: tabs are layout viewports,
-- buffers are open files.  Reaching for a bufferline to manage open
-- files often signals that a fuzzy-finder or :ls would be a more
-- effective habit - but if you prefer this workflow, just copy this
-- file to lua/user/plugins/bufferline.lua.
--
-- See :help noethervim-tabline-bufferline for more details.

return {
  "akinsho/bufferline.nvim",
  event = "UIEnter",
  dependencies = "nvim-tree/nvim-web-devicons",
  opts = {},
  config = function(_, opts)
    require("bufferline").setup(opts)
    -- Disable heirline's tabline so bufferline owns the area.
    vim.o.tabline = ""
    vim.o.showtabline = 2
  end,
}
