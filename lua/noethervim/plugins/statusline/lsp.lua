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
      -- `:LspInfo` was a nvim-lspconfig command and is gone; the built-in
      -- report replaced it. Fall back only if something still defines it.
      --
      -- In a float, because every other clickable component opens one, and
      -- a click that replaces the buffer you were looking at is a click you
      -- have to undo. `vim.g.health.style` is the supported way to ask for
      -- it; set around the call rather than globally so a typed
      -- `:checkhealth` still opens however the user prefers.
      vim.defer_fn(function()
        if vim.fn.exists(":LspInfo") == 2 then
          vim.cmd("LspInfo")
          return
        end
        -- The report opens through `vim.lsp.util.open_floating_preview`,
        -- which takes its border from 'winborder'. Rounded, to match the
        -- hover and signature floats and the popups the other statusline
        -- components open.
        local health, border = vim.g.health, vim.o.winborder
        vim.g.health = vim.tbl_extend("force", health or {}, { style = "float" })
        vim.o.winborder = "rounded"
        local ok, err = pcall(vim.cmd, "checkhealth vim.lsp")
        vim.g.health, vim.o.winborder = health, border
        if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
      end, 100)
    end,
    name = "heirline_LSP",
  },

  hl = function()
    local filetype = vim.bo.filetype
    if not ctx.lspColor[filetype] then
      return { bold = true, fg = ctx.colors.text_gray }
    end
    return { bold = true, fg = ctx.lspColor[filetype] }
  end,

  flexible = ctx.priority.mid_low,
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
