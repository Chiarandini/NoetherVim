-- LSP active indicator statusline component.

local ctx = require("noethervim.plugins.statusline.context")
local icons = require("noethervim.util.icons")
local conditions = require("heirline.conditions")

local M = {}

M.LSPActive = {
  condition = function()
    return conditions.lsp_attached() and vim.g.heirline_lsp_show
  end,
  on_click = {
    callback = function()
      vim.defer_fn(function()
        vim.cmd("LspInfo")
      end, 100)
    end,
    name = "heirline_LSP",
  },

  hl = function()
    local filetype = vim.bo.filetype
    if not ctx.lspColor[filetype] then
      return { bold = true, fg = "white" }
    end
    return { bold = true, fg = ctx.lspColor[filetype] }
  end,

  flexible = ctx.priority.mid,
  { -- render all the servers
    provider = function()
      local names = {}
      for _, server in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
        table.insert(names, server.name)
      end
      return icons.nvim_lsp .. "(" .. table.concat(names, ", ") .. ")"
    end,
  },
  { -- render just that the lsp is active
    provider = icons.nvim_lsp,
  },
}

return M
