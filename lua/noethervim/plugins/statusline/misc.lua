-- Small utility and miscellaneous statusline components.

local ctx = require("noethervim.plugins.statusline.context")
local icons = require("noethervim.util.icons")
local utils = require("heirline.utils")

local M = {}

-- Spacing and separating components
M.Align = { provider = "%=" }
M.Seperator = { flexible = ctx.priority.mid, { provider = "|" }, { provider = "" } }
M.Space = { provider = " " }

-- Luasnip jump detecting
M.Jumpable = {
  condition = function()
    return vim.tbl_contains({ "s", "i" }, vim.fn.mode())
  end,
  provider = function()
    local forward = require("luasnip").jumpable(1) and " " or ""
    local backward = require("luasnip").jumpable(-1) and " " or ""
    return backward .. forward
  end,
  hl = { fg = "green", bold = true },
}

-- Recording macro
M.MacroRec = {
  condition = function()
    return vim.fn.reg_recording() ~= "" -- and vim.o.cmdheight == 0
  end,
  provider = " ",
  hl = { fg = "orange", bold = true },
  utils.surround({ "[", "]" }, nil, {
    provider = function()
      return vim.fn.reg_recording()
    end,
    hl = { fg = "green", bold = true },
  }),
  update = {
    "RecordingEnter",
    "RecordingLeave",
    "InsertEnter",
    "InsertLeave",
  },
}

-- Filetype
M.FileType = {
  provider = function()
    return vim.bo.filetype
  end,
  hl = function() return { fg = utils.get_highlight("Type").fg, bold = true } end,
}

-- Help filename
M.HelpFileName = {
  condition = function()
    return vim.bo.filetype == "help"
  end,
  provider = function()
    local filename = vim.api.nvim_buf_get_name(0)
    return vim.fn.fnamemodify(filename, ":t")
  end,
  hl = function() return { fg = ctx.colors.blue } end,
}

-- Terminal info
M.TerminalName = {
  provider = function()
    local tname, _ = vim.api.nvim_buf_get_name(0):gsub(".*:", "")
    if tname:match("dap%-terminal") then
      return "  dap-terminal"
    end
    return "  " .. tname
  end,
  hl = function() return { fg = ctx.colors.green, bg = ctx.colors.default_gray, bold = true } end,
}

-- Lazy plugin has updates
M.Lazy = {
  condition = require("lazy.status").has_updates,

  on_click = {
    callback = function()
      require("lazy").home()
    end,
    name = "update_plugins",
  },
  hl = function() return { fg = ctx.colors.lazy_updates } end,

  flexible = ctx.priority.none,
  {
    provider = function()
      return require("lazy.status").updates() .. " "
    end,
  },
  {
    provider = "",
  },
}

return M
