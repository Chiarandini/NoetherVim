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

    -- searchcount compiles @/ as a regex; invalid patterns (e.g. "S**") raise
    -- E871 and similar. Swallow them so the statusline stays quiet.
    local ok, search_count = pcall(vim.fn.searchcount, { recompute = 1, maxcount = -1 })
    if not ok then
      return
    end
    local active = false
    if vim.v.hlsearch and vim.v.hlsearch == 1
        and search_count and search_count.total and search_count.total > 0 then
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
    --- Centred in the mode chip, which Vim's own width syntax cannot do.
    --- `%7(...%)` sets a minimum width and right-aligns inside it, so a short
    --- count sat off to the right: `0/1` rendered as `"   0/1 "`, three
    --- spaces to the left and one to the right. Only short counts were
    --- affected, which is why it looked like a one-off rather than a rule.
    ---
    --- Splitting the padding by hand is exact at every width, and the chip
    --- still grows past seven once the numbers need it.
    provider = function(self)
      local text  = ("%s/%s"):format(self.count.current, self.count.total)
      local width = math.max(7, #text + 2)
      local pad   = width - #text
      local left  = math.floor(pad / 2)
      return string.rep(" ", left) .. text .. string.rep(" ", pad - left)
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
    -- TODO: this is specific to japanese; it must be updated and most likely exposed in config.lua
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
