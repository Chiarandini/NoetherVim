-- Tabline statusline components.

local ctx = require("noethervim.plugins.statusline.context")
local utils = require("heirline.utils")

local M = {}

local TablineFileIcon = {
  init = function(self)
    local filename = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(self.tabpage)))
    local extension = vim.fn.fnamemodify(filename, ":e")
    self.icon, self.icon_color =
        require("nvim-web-devicons").get_icon_color(filename, extension, { default = true })
  end,
  provider = function(self)
    return self.icon and (self.icon .. " ")
  end,
  hl = function(self)
    return { fg = self.icon_color }
  end,
}

local TabLineOffset = {
  condition = function(self)
    local win = vim.api.nvim_tabpage_list_wins(0)[1]
    local bufnr = vim.api.nvim_win_get_buf(win)
    self.winid = win

    if vim.bo[bufnr].filetype == "snacks_layout_box" then
      self.title = ""
      return true
      -- elseif vim.bo[bufnr].filetype == "TagBar" then
      --     ...
    end
  end,

  provider = function(self)
    local title = self.title
    local width = vim.api.nvim_win_get_width(self.winid)
    local pad = math.ceil((width - #title) / 2)
    return string.rep(" ", pad) .. title .. string.rep(" ", pad)
  end,

  hl = function(self)
    if vim.api.nvim_get_current_win() == self.winid then
      return "TablineSel"
    else
      return "Tabline"
    end
  end,
}

--- Check whether any buffer visible in a tabpage has unsaved changes.
local function tab_modified(tabpage)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].modified then
      return true
    end
  end
  return false
end

local TablineModified = {
  condition = function(self)
    return tab_modified(self.tabpage)
  end,
  provider = function()
    return require("noethervim.statusline").get_tab_modified_indicator()
  end,
  hl = function(self)
    if self.is_active then
      return { fg = ctx.colors.text_gray, bg = ctx.colors.light_gray }
    else
      return { fg = ctx.colors.text_unselected, bg = ctx.colors.default_gray }
    end
  end,
}

local TablineCloseButton = {
  provider = function(self)
    return "%" .. self.tabnr .. "X 󰅖 %X"
  end,
  hl = function(self)
    if self.is_active then
      return { fg = ctx.colors.text_gray, bg = ctx.colors.light_gray }
    else
      return { fg = ctx.colors.text_unselected, bg = ctx.colors.default_gray }
    end
  end,
}

--- Resolve the display name for a tab's focused buffer.
--- Returns project_name, filename (project_name may be nil).
local function tab_display_name(tabpage)
  local filename = vim.api.nvim_buf_get_name(
    vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(tabpage)))

  if filename == "" then
    return nil, "[No Name]"
  end

  local ok, expanded = pcall(vim.fn.expand, filename)
  if not ok or expanded == "" then
    return nil, vim.fn.fnamemodify(filename, ":t")
  end

  local git_root = ctx.cached_git_root(vim.fn.fnamemodify(expanded, ":h"))
  if git_root == "" then
    return nil, vim.fn.fnamemodify(filename, ":t")
  end

  local project = git_root:match("[^/]+$") or git_root
  return project, vim.fn.fnamemodify(filename, ":t")
end

local Tab = utils.surround({ "", "" }, function(self)
  if self.is_active then
    return ctx.colors.light_gray
  else
    return ctx.colors.default_gray
  end
end, {
  TablineFileIcon,
  {
    init = function(self)
      self.project, self.filename = tab_display_name(self.tabpage)
    end,
    -- Flexible: degrade from "project: file" → "file" as space shrinks.
    flexible = ctx.priority.mid,
    {
      provider = function(self)
        local label = self.project
            and (self.project .. ": " .. self.filename)
            or self.filename
        return "%" .. self.tabnr .. "T " .. label .. " %T"
      end,
    },
    {
      provider = function(self)
        return "%" .. self.tabnr .. "T " .. self.filename .. " %T"
      end,
    },
  },
  TablineModified,
  TablineCloseButton,
  hl = function(self)
    if self.is_active then
      return { fg = ctx.colors.text_gray, bg = ctx.colors.light_gray }
    else
      return { fg = ctx.colors.text_unselected, bg = ctx.colors.default_gray }
    end
  end,
})

-- The bar behind the tabs, and what the tab separators carve against. It is
-- the editor background rather than `default_gray` so the three levels stay
-- distinct: bar at `bg`, inactive tab at `default_gray`, active tab at
-- `light_gray`. With the bar and the inactive tabs both `default_gray` an
-- unselected tab had no edge at all -- its body matched the bar and its
-- separators, drawn in the tab's own colour, matched it too.
local function tabline_bg()
  return ctx.colors.bg
end

local TablineFill = {
  provider = "%=",
  hl = function()
    return { bg = tabline_bg() }
  end,
}

-- ── Which tabs get drawn ─────────────────────────────────────────────
-- With more tabs than columns, Vim truncates the tabline at the right edge
-- and leaves a `<`. That drops whichever tabs do not fit, and the active
-- one is as droppable as the rest -- so the moment you move past the edge
-- the bar stops telling you which tab you are on, which is the one thing
-- it exists to say.
--
-- Render a contiguous window that always contains the active tab instead,
-- with markers for what was left off either side. `make_tablist` is only a
-- convenience wrapper for "one child per tabpage", so this is its init with
-- a range in place of the whole list; nothing about heirline had to change.
local visible = { lo = 1, hi = 0, total = 0 }

--- Rendered width of a tab, ignoring the flexible label degradation. Two
--- separators, an icon and a space, the label, the close button, and a
--- modified glyph when it applies.
local function tab_width(tabpage)
  local project, filename = tab_display_name(tabpage)
  local label = project and (project .. ": " .. filename) or filename
  return vim.fn.strdisplaywidth(label) + 8 + (tab_modified(tabpage) and 2 or 0)
end

--- The widest window of tabs around `active` that fits in `budget` columns.
--- Grows rightwards first so the strip reads in tab order.
local function fit_window(tabpages, active, budget)
  local lo, hi = active, active
  local used = tab_width(tabpages[active])
  while true do
    local grew = false
    if hi < #tabpages then
      local w = tab_width(tabpages[hi + 1])
      if used + w <= budget then hi, used, grew = hi + 1, used + w, true end
    end
    if lo > 1 then
      local w = tab_width(tabpages[lo - 1])
      if used + w <= budget then lo, used, grew = lo - 1, used + w, true end
    end
    if not grew then break end
  end
  return lo, hi
end

--- Marker for tabs scrolled off one side. Carries the count, because "there
--- is more" and "there are nine more" are different situations.
local function overflow(side)
  return {
    condition = function()
      return side == "left" and visible.lo > 1 or side == "right" and visible.hi < visible.total
    end,
    provider = function()
      local n = side == "left" and (visible.lo - 1) or (visible.total - visible.hi)
      return side == "left" and (" ‹" .. n .. " ") or (" " .. n .. "› ")
    end,
    hl = function()
      return { fg = ctx.colors.text_unselected, bg = tabline_bg() }
    end,
  }
end

local TabList = {
  init = function(self)
    local tabpages = vim.api.nvim_list_tabpages()
    local current = vim.api.nvim_get_current_tabpage()
    local active = 1
    for i, tabpage in ipairs(tabpages) do
      if tabpage == current then active = i end
    end

    -- Leave room for the overflow markers themselves.
    local lo, hi = fit_window(tabpages, active, math.max(vim.o.columns - 12, 20))
    visible.lo, visible.hi, visible.total = lo, hi, #tabpages

    local n = 0
    for i = lo, hi do
      n = n + 1
      local tabpage = tabpages[i]
      local child = self[n]
      if not (child and child.tabpage == tabpage) then
        self[n] = self:new(Tab, n)
        child = self[n]
      end
      child.tabnr = vim.api.nvim_tabpage_get_number(tabpage)
      child.tabpage = tabpage
      child.is_active = (tabpage == current)
    end
    for i = #self, n + 1, -1 do
      self[i] = nil
    end
  end,
}

M.TabPages = {
  condition = function()
    return #vim.api.nvim_list_tabpages() >= 1
  end,
  -- The tab separators are drawn by `utils.surround`, which colours the
  -- glyph with the tab's own background and leaves the glyph's background
  -- to the parent. Without one here that fell through to the theme's
  -- TabLineFill, which agrees with the bar under gruvbox and visibly does
  -- not under other themes.
  hl = function()
    return { bg = tabline_bg() }
  end,
  TabLineOffset,
  overflow("left"),
  TabList,
  overflow("right"),
  TablineFill,
}

return M
