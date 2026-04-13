-- ViMode component: mode indicator with search results, oil, and keyboard overlays.

local ctx = require("noethervim.plugins.statusline.context")
local utils = require("heirline.utils")

local M = {}

local SearchResults = {
  condition = function(self)
    local lines = vim.api.nvim_buf_line_count(0)
    if lines > 50000 then -- prevent lag
      return
    end

    local query = vim.fn.getreg("/")
    if query == "" then -- prevent empty queries
      return
    end

    if query:find("@") then
      return
    end

    if query:find("\\v") then
      return -- don't do regex, it breaks down
    end

    local search_count = vim.fn.searchcount({ recompute = 1, maxcount = -1 })
    local active = false
    if vim.v.hlsearch and vim.v.hlsearch == 1 and search_count.total > 0 then
      active = true
    end
    if not active then
      return
    end

    query = query:gsub([[^\V]], "")
    query = query:gsub([[\<]], ""):gsub([[\>]], "")

    self.query = query
    self.count = search_count
    return true
  end,
  {
    provider = function(self)
      return "%7("
          .. table.concat({
            " ",
            self.count.current,
            "/",
            self.count.total,
            " ",
          })
          .. "%)"
    end,
  },
  { provider = " " }, -- separator after, if section is active
}

local OilCircle = {
  condition = function()
    return vim.o.filetype == "oil"
  end,
  hl = function() return { fg = ctx.colors.default_blue } end,
  provider = function()
    return "Oil"
  end,
}

local KeyboardMode = {
  condition = function()
    return vim.g.KeyboardMode == true
  end,
  hl = function() return { fg = ctx.colors.default_blue } end,
  provider = function()
    return "J"
  end,
}

M.ViMode = {
  init = function(self)
    self.mode = vim.fn.mode(1) -- :h mode()
  end,

  utils.surround(ctx.semiCircles, function()
    local mode = vim.fn.mode(1):sub(1, 1) -- get only the first mode character
    local has_luasnip, luasnip = pcall(require, "luasnip")
    if has_luasnip and luasnip.jumpable() then
      return ctx.colors.light_green
    end
    return ctx.mode_colors[mode]
  end, {
    hl = function(self)
      local mode = self.mode:sub(1, 1) -- get only the first mode character
      local has_luasnip, luasnip = pcall(require, "luasnip")
      if has_luasnip and luasnip.jumpable() then
        return { bg = ctx.colors.light_green, fg = ctx.colors.dark_green, bold = true }
      end
      return { bg = ctx.mode_colors[mode], fg = ctx.colors.dark_green, bold = true }
    end,
    fallthrough = false, -- stop at first child that evaluates to true
    SearchResults,
    OilCircle,
    KeyboardMode,
    {
      flexible = ctx.priority.high,
      -- show the large bar
      { provider = "%7(%)" },
      -- show the mid-size bar
      { provider = "%3(%)" },
      -- show the small bar
      { provider = "%1(%)" },
      -- show the circle
      { provider = "%(%) " },
    },
  }),
}

return M
