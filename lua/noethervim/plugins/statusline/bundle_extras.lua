-- Bundle-specific statusline components (VimTeX, PDF size, Overseer, DAP).
-- These components have condition guards so they only render when their
-- respective bundles are active.

local ctx = require("noethervim.plugins.statusline.context")
local icons = require("noethervim.util.icons")
local utils = require("heirline.utils")

local M = {}

-- DAP status
M.DAPMessages = {
  condition = function()
    local plugins = require("lazy.core.config").plugins
    local nvim_dap_plugin = plugins["nvim-dap"]

    if nvim_dap_plugin and nvim_dap_plugin._.loaded then
      local session = require("dap").session()
      return session ~= nil
    end
    return false
  end,
  provider = function()
    return "  " .. require("dap").status() .. " "
  end,
  hl = function() return utils.get_highlight("Debug") end,
}

-- VimTeX compiler status
M.VimtexCompilerStatus = {
  init = function(self)
    ---@diagnostic disable-next-line: undefined-field
    self.status = vim.b.vimtex.compiler.status
    self.color = "white" -- default
  end,
  condition = function()
    ---@diagnostic disable-next-line: undefined-field
    return vim.b.vimtex ~= nil and vim.b.vimtex.compiler ~= nil
  end,
  flexible = ctx.priority.max,
  hl = function(self)
    if self.status == 1 then return { fg = ctx.colors.orange }
    elseif self.status == 2 then return { fg = ctx.colors.light_green }
    elseif self.status == 3 then return { fg = ctx.colors.light_red }
    end
    return {}
  end,
  provider = function(self)
    if self.status == 1 then
      return "compiling " .. icons.text
    elseif self.status == 2 then
      return "done, stand by " .. icons.checkmark
    elseif self.status == 3 then
      return "compilation error " .. icons.error
    end
    return ""
  end,
}

-- PDF file size
M.PdfFileSize = {
  condition = function()
    return vim.g.heirline_pdfsize_show
  end,
  provider = function()
    local file = tostring(vim.fn.expand("%:p:r")) .. ".pdf"
    local result = vim.api.nvim_call_function("getfsize", { file })
    if result > 0 then
      return "size: " .. result .. " b"
    else
      return "no " .. tostring(vim.fn.expand("%:r")) .. ".pdf found"
    end
  end,
  hl = function() return { fg = ctx.colors.text_gray } end,
}

-- Overseer task status
M.Overseer = {
  condition = function()
    local ok, _ = pcall(require, "overseer")
    if ok then
      return true
    end
  end,
  init = function(self)
    self.overseer = require("overseer")
    self.tasks = self.overseer.task_list
    self.STATUS = self.overseer.constants.STATUS
  end,
  static = {
    symbols = {
      ["FAILURE"] = "  ",
      ["CANCELED"] = "  ",
      ["SUCCESS"] = "  ",
      ["RUNNING"] = " 省",
    },
    colors = {
      ["FAILURE"] = "red",
      ["CANCELED"] = "gray",
      ["SUCCESS"] = "green",
      ["RUNNING"] = "yellow",
    },
  },
  {
    condition = function(self)
      return #self.tasks.list_tasks() > 0
    end,
    {
      provider = function(self)
        local tasks_by_status =
            self.overseer.util.tbl_group_by(self.tasks.list_tasks({ unique = true }), "status")

        for _, status in ipairs(self.STATUS.values) do
          local status_tasks = tasks_by_status[status]
          if self.symbols[status] and status_tasks then
            self.color = self.colors[status]
            return self.symbols[status]
          end
        end
      end,
      hl = function(self)
        return { fg = self.color }
      end,
    },
  },
}

return M
