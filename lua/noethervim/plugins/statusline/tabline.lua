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
  provider = " ●",
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

local TablineFill = {
  provider = "%=",
  hl = function()
    return { bg = ctx.colors.default_gray }
  end,
}

M.TabPages = {
  condition = function()
    return #vim.api.nvim_list_tabpages() >= 1
  end,
  TabLineOffset,
  utils.make_tablist(Tab),
  TablineFill,
}

return M
