-- Small utility and miscellaneous statusline components.

local ctx = require("noethervim.plugins.statusline.context")
local icons = require("noethervim.util.icons")
local utils = require("heirline.utils")

local M = {}

-- Spacing and separating components
M.Align = { provider = "%=" }
M.Separator = { flexible = ctx.priority.mid, { provider = "|" }, { provider = "" } }
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

-- Buffer 'busy' status (Nvim 0.12+). Any plugin can increment vim.bo.busy
-- to signal work in progress; we render an animated spinner while the
-- counter is positive on any visible buffer. The timer is demand-driven:
-- it only runs while something is actually busy.
local busy_frames = { "◐", "◓", "◑", "◒" }
local busy_frame = 1
local busy_timer = nil

local function any_win_busy()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if (vim.bo[vim.api.nvim_win_get_buf(win)].busy or 0) > 0 then
      return true
    end
  end
  return false
end

local function stop_busy()
  if busy_timer then
    busy_timer:stop()
    busy_timer:close()
    busy_timer = nil
  end
end

local function start_busy()
  if busy_timer then return end
  busy_timer = vim.uv.new_timer()
  busy_timer:start(100, 100, vim.schedule_wrap(function()
    if any_win_busy() then
      busy_frame = busy_frame % #busy_frames + 1
      vim.cmd.redrawstatus()
    else
      stop_busy()
    end
  end))
end

vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "busy",
  group = vim.api.nvim_create_augroup("noethervim_busy_spinner", { clear = true }),
  callback = function()
    if any_win_busy() then start_busy() else stop_busy() end
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("noethervim_busy_cleanup", { clear = true }),
  callback = stop_busy,
})

M.Busy = {
  condition = function()
    return (vim.bo.busy or 0) > 0
  end,
  provider = function()
    return busy_frames[busy_frame] .. " "
  end,
  hl = { fg = "orange", bold = true },
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
