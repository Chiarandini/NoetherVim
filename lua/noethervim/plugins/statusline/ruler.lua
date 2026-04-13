-- Position, percentage, and file size statusline components.

local ctx = require("noethervim.plugins.statusline.context")

local M = {}

M.Pos = {
  -- %l = current line number
  -- %L = number of lines in the buffer
  -- %c = column number
  -- %P = percentage through file of displayed window
  flexible = ctx.priority.high,

  hl = function(self)
    local mode = vim.fn.mode(1):sub(1, 1) -- get only the first mode character
    return { bg = ctx.mode_colors[mode], fg = ctx.colors.dark_green, bold = true }
  end,
  {
    { provider = " " },
    provider = "%7(%l:%2c%)",
    { provider = " " },
  },
  { provider = "%7(%l:%2c%)" },
}

M.Percentage = {
  flexible = ctx.priority.mid,
  { provider = " %p%%" },
  { provider = "" },
}

M.FileSize = {
  flexible = ctx.priority.none,
  {
    provider = function()
      -- stackoverflow, compute human readable file size
      local suffix = { "b", "k", "M", "G", "T", "P", "E" }
      local fsize = vim.fn.getfsize(vim.api.nvim_buf_get_name(0))
      fsize = (fsize < 0 and 0) or fsize
      if fsize < 1024 then
        return fsize .. suffix[1]
      end
      local i = math.floor((math.log(fsize) / math.log(1024)))
      return string.format("%.3g%s", fsize / math.pow(1024, i), suffix[i + 1])
    end,
  },
  { provider = "" },
}

return M
