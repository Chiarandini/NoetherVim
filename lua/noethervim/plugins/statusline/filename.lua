-- Filename-related statusline components.

local ctx = require("noethervim.plugins.statusline.context")
local icons = require("noethervim.util.icons")
local nv = require("noethervim.util")
local utils = require("heirline.utils")

local M = {}

local save_warning = "Not saving in same directory!"

local function warning_popup(text)
  local mouse_pos = vim.fn.getmousepos()
  local opts = {
    relative = "editor",
    row = mouse_pos.screenrow,
    col = mouse_pos.screencol,
    width = string.len(text) + 2,
    height = 1,
    style = "minimal",
    border = "rounded",
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
  vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { scope = "local", buf = buf })

  local win = vim.api.nvim_open_win(buf, false, opts)

  vim.keymap.set("n", "q", "<cmd>q<CR>", { buf = buf, noremap = true, silent = true })

  vim.api.nvim_set_current_win(win)
end

local function out_of_sync_popup()
  local lines = {
    " Buffer and disk file are out of sync. ",
    " [D]iff   [C]ancel ",
  }
  local width = 0
  for _, l in ipairs(lines) do
    if #l > width then width = #l end
  end

  local mouse_pos = vim.fn.getmousepos()
  local opts = {
    relative = "editor",
    row      = math.max(0, mouse_pos.screenrow - #lines - 2),
    col      = mouse_pos.screencol,
    width    = width,
    height   = #lines,
    style    = "minimal",
    border   = "rounded",
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = buf })
  vim.api.nvim_set_option_value("bufhidden",  "wipe",  { scope = "local", buf = buf })

  local win = vim.api.nvim_open_win(buf, true, opts)

  local function close() pcall(vim.api.nvim_win_close, win, true) end
  local function diff() close(); vim.cmd("DiffOrig") end

  local km = { buffer = buf, noremap = true, silent = true, nowait = true }
  vim.keymap.set("n", "d",     diff,  km)
  vim.keymap.set("n", "y",     diff,  km)
  vim.keymap.set("n", "<CR>",  diff,  km)
  vim.keymap.set("n", "c",     close, km)
  vim.keymap.set("n", "n",     close, km)
  vim.keymap.set("n", "q",     close, km)
  vim.keymap.set("n", "<Esc>", close, km)
end

local function ProjRelativeFilename()
  local filePath = vim.fn.expand("%:p:h")
  local gitPath = ctx.cached_git_root(filePath)
  local relativePath = nv.str_replace(filePath, gitPath, "")
  if relativePath ~= "" then
    return relativePath
  end
  return vim.api.nvim_buf_get_name(0)
end

local function OilRelativeFilename()
  local oil_prefix = "oil:///"
  local path = string.sub(vim.fn.expand("%:p:h"), #oil_prefix + 1)
  local gitPath = ctx.cached_git_root(path)
  local filePath = vim.fn.expand("%:p")
  local relativePath = nv.str_replace(filePath, gitPath, "")
  if relativePath ~= "" then
    return relativePath
  end
  return vim.api.nvim_buf_get_name(0)
end

local WorkDir = {
  init = function(self)
    self.icon = " "
    self.cwd = vim.fs.normalize(ProjRelativeFilename())
  end,
  condition = function()
    return vim.g.heirline_directory_show
  end,
  hl = { fg = "orange", bold = true },

  flexible = ctx.priority.high,

  {
    -- evaluates to the full-length path
    provider = function(self)
      local trail = self.cwd:sub(-1) == "/" and "" or "/"
      return self.icon .. self.cwd .. trail
    end,
  },
  {
    -- evaluates to the shortened path
    provider = function(self)
      local cwd = vim.fn.pathshorten(self.cwd)
      local trail = self.cwd:sub(-1) == "/" and "" or "/"
      return self.icon .. cwd .. trail
    end,
  },
  {
    -- evaluates to "", hiding the component
    provider = " ",
  },
}

M.FileIcon = {
  init = function(self)
    local filename = vim.api.nvim_buf_get_name(0)
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

local BufNotCwdWarning = {
  condition = function()
    local relativeFilename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
    local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
    return relativeFilename ~= filename
  end,
  on_click = {
    callback = function()
      warning_popup(save_warning)
    end,
    name = "heirline_save_warning",
  },
  provider = " " .. icons.warning .. " ",
  hl = function() return { fg = ctx.colors.red } end,
}

M.FileName = {
  on_click = {
    callback = function()
      if vim.fn.has("macunix") == 1 then
        vim.cmd("!open .")
      elseif vim.fn.has("win32") == 1 then
        vim.cmd("!explorer .")
      else
        vim.cmd("!xdg-open .")
      end
    end,
    name = "heirline_file_explorer",
  },
  provider = function(self)
    -- either get filename or get it relative to project:
    if vim.g.heirline_proj_relative_dir_show then
      return ProjRelativeFilename()
    end
    -- first, trim the pattern relative to the current directory.
    -- For other options, see :h filename-modifers
    local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
    if filename == "" then
      return "[No Name]"
    end
    return filename
  end,
  hl = function() return { fg = ctx.colors.text_gray } end,
}

M.ReadOnlyFlag = {
  condition = function()
    return not vim.bo.modifiable or vim.bo.readonly
  end,
  hl = function() return { force = true, fg = ctx.colors.light_red, bg = ctx.colors.light_gray } end,
  provider = icons.lock .. " ",
}

M.ScratchFlag = {
  condition = function()
    return vim.api.nvim_buf_get_name(0) == "" and vim.bo.buftype == "" and vim.bo.filetype == ""
  end,
  hl = function()
    local bg = vim.fn.mode(1):sub(1, 1) == "i" and ctx.colors.medium_blue or ctx.colors.light_gray
    return { force = true, fg = ctx.colors.blue, bg = bg }
  end,
  provider = "󰎞 ",
}

M.ChangeFlag = {
  condition = function()
    return vim.bo.modified
  end,
  hl = function()
    return { fg = vim.b.noethervim_out_of_sync and ctx.colors.red or "orange" }
  end,
  on_click = {
    callback = function()
      if vim.b.noethervim_out_of_sync then
        out_of_sync_popup()
      else
        vim.cmd("DiffOrig")
      end
    end,
    name = "heirline_unsaved_diff",
  },
  provider = function()
    if vim.b.noethervim_out_of_sync then
      return icons.warning .. " "
    end
    return icons.pencil .. " "
  end,
}

local FileNameModifer = {
  hl = function()
    if vim.bo.modified then
      -- use `force` because we need to override the child's hl foreground
      return { force = true, fg = ctx.colors.light_orange }
    end
  end,
}

M.FileNameBlock = {
  -- let's first set up some attributes needed by this component and its children
  init = function(self)
    self.filename = vim.api.nvim_buf_get_name(0)
  end,

  WorkDir,
  {
    BufNotCwdWarning,
    utils.insert(FileNameModifer, M.FileName), -- a new table where FileName is a child of FileNameModifier
    { provider = "%<" },                       -- statusline is cut here when there's not enough space
  },
}

M.OilBuffer = {
  -- let's first set up some attributes needed by this component and its children
  init = function(self)
    self.filename = vim.api.nvim_buf_get_name(0)
  end,

  on_click = {
    callback = function()
      if vim.fn.has("macunix") == 1 then
        vim.cmd("!open .")
      elseif vim.fn.has("win32") == 1 then
        vim.cmd("!explorer .")
      else
        vim.cmd("!xdg-open .")
      end
    end,
    name = "heirline_file_explorer",
  },
  {
    provider = function()
      local path = OilRelativeFilename()
      local oil_prefix = "oil:///"
      local last_slash_index = string.match(path, "(.*)/[^/]+/?$")
      if last_slash_index then
        return string.sub(last_slash_index, #oil_prefix + 1) .. "/"
      end
      return string.sub(path, #oil_prefix + 1)
    end,
    hl = { fg = "orange", bold = true },
  },
  {
    provider = function(self)
      local buf_name = vim.api.nvim_buf_get_name(0)
      local oil_prefix = "oil:///"
      local path = string.sub(buf_name, #oil_prefix + 1)
      local dir_name = string.match(path, "([^/]+)/?$")
      return dir_name .. "/"
    end,
  },
  hl = function() return { fg = ctx.colors.text_gray } end,
}

return M
