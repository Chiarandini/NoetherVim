-- ViMode component: mode indicator with search results, oil, and keyboard overlays.

local ctx = require("noethervim.plugins.statusline.context")
local utils = require("heirline.utils")

local M = {}

--- Centred in the mode chip, which Vim's own width syntax cannot do.
--- `%7(...%)` sets a minimum width and right-aligns inside it, so a short
--- count sat off to the right: `0/1` rendered as `"   0/1 "`, three spaces
--- to the left and one to the right. Only short counts were affected, which
--- is why it looked like a one-off rather than a rule.
---
--- Splitting the padding by hand is exact at every width, and the chip still
--- grows past seven once the numbers need it.
local function chip(text)
  local width = math.max(7, #text + 2)
  local pad   = width - #text
  local left  = math.floor(pad / 2)
  return string.rep(" ", left) .. text .. string.rep(" ", pad - left)
end

--- Match count for the pattern in `@/`, or nil when there is nothing to count.
--- `maxcount = -1` scans the whole buffer on every redraw, hence the ceiling.
--- searchcount compiles `@/` as a regex; invalid patterns (e.g. "S**") raise
--- E871 and similar, so the call is wrapped.
local function match_count()
  if vim.api.nvim_buf_line_count(0) > 50000 then
    return
  end
  local query = vim.fn.getreg("/")
  if query == "" or query:find("@") then
    return
  end
  local ok, count = pcall(vim.fn.searchcount, { recompute = 1, maxcount = -1 })
  if ok and count and count.total and count.total > 0 then
    return count
  end
end

-- Progress through a `:s///c`, shown while the replace prompt is up (`r?` is
-- the mode Vim reports during it). Nothing reports how far along the pass is,
-- so it is derived from the same counter the search chip uses: `:s` sets `@/`,
-- and `total - current + 1` is the number of matches still to be offered
-- whether or not the replacement text matches the pattern again. Freezing that
-- on the first prompt gives a denominator that holds for the whole run, so the
-- chip counts up `1/12`, `2/12`, ... including matches skipped with `n`.
--
-- The run is bounded by the Ex command line that starts it, not by the mode:
-- Vim drops back to normal between every confirmation, so `r?` alone cannot
-- tell a fresh run from the next prompt of the current one. The prompt itself
-- is a command line of type `-`, which is why the reset is scoped to `:`.
-- `g&` and `:&&` repeat a substitute without one, hence the second arming rule
-- -- more matches left than the frozen total means a new pass has begun.
local sub_total ---@type integer?

vim.api.nvim_create_autocmd("CmdlineLeave", {
  group    = vim.api.nvim_create_augroup("noethervim_statusline_substitute", { clear = true }),
  pattern  = ":",
  callback = function() sub_total = nil end,
})

local SubstituteProgress = {
  condition = function(self)
    if vim.fn.mode(1) ~= "r?" then
      return
    end
    local count = match_count()
    if not count then
      return
    end
    local left = count.total - math.max(count.current, 1) + 1
    if not sub_total or left > sub_total then
      sub_total = left
    end
    self.done  = math.min(sub_total, math.max(1, sub_total - left + 1))
    self.total = sub_total
    return true
  end,
  { provider = function(self) return chip(("%d/%d"):format(self.done, self.total)) end },
  { provider = " " },
}

local SearchResults = {
  condition = function(self)
    if vim.v.hlsearch ~= 1 then
      return
    end
    self.count = match_count()
    return self.count ~= nil
  end,
  {
    provider = function(self)
      return chip(("%s/%s"):format(self.count.current, self.count.total))
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
    SubstituteProgress,
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
