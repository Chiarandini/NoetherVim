-- Filename-related statusline components.

local ctx = require("noethervim.plugins.statusline.context")
local icons = require("noethervim.util.icons")
local nv = require("noethervim.util")
local utils = require("heirline.utils")

local M = {}

-- ── Buffer directory vs. working directory ───────────────────────────────
--
-- Neovim's working directory belongs to the window (falling back to the tab,
-- then to the global one), never to the buffer. Editing `docs/a.md` from a
-- cwd of the project root leaves cwd at the root, so a *relative* write
-- argument goes to the root rather than next to the file on screen:
--
--     :e docs/a.md        cwd stays at the project root
--     :w draft.md         writes <root>/draft.md, not <root>/docs/draft.md
--
-- `:w` with no argument is never affected. Neovim expands a buffer's name
-- to an absolute path when the buffer is created -- confirmed for `:edit`,
-- `:file` and `nvim_buf_set_name()` alike -- so a plain write always goes
-- back to the file it read, whatever cwd has done since.
--
-- Two tiers, because the two cases are not equally surprising:
--
--   inside   the file sits somewhere under cwd. Ordinary project
--            navigation; rendered dimmed, as orientation rather than alarm.
--   outside  the file is not under cwd at all. Rare, and the case where a
--            relative `:w` or `:e` most likely lands somewhere unrelated to
--            anything visible; rendered in the warning colour.
--
-- The two tiers are what keep this readable as signal. Under Neovim's
-- default of 'noautochdir', "buffer directory differs from cwd" is true of
-- every file in a subdirectory, which is most of them; a single undifferentiated
-- marker would be lit almost always and mean almost nothing.

---Classify the current buffer's directory against the window's cwd.
---@return "inside"|"outside"|nil  nil when they agree, or there is no file
local function cwd_state()
  if vim.bo.buftype ~= "" then return nil end
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then return nil end

  local dir = vim.fs.normalize(vim.fn.fnamemodify(name, ":p:h"))
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  if dir == cwd then return nil end

  local prefix = cwd == "/" and "/" or (cwd .. "/")
  return vim.startswith(dir .. "/", prefix) and "inside" or "outside"
end

---Explain the divergence and offer the window-local fix.
---
---`:lcd` rather than `:cd` on purpose: `:cd` from a window holding a
---window-local or tab-local directory silently discards both.
local function cwd_popup()
  local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
  local lines = {
    " cwd:  " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":~"),
    " file: " .. vim.fn.fnamemodify(dir, ":~"),
    " Relative :w and :e resolve against cwd. ",
    " [L] :lcd to this file's directory   [C]ancel ",
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
  local function lcd()
    close()
    vim.cmd("lcd " .. vim.fn.fnameescape(dir))
    vim.cmd.redrawstatus()
  end

  local km = { buffer = buf, noremap = true, silent = true, nowait = true }
  vim.keymap.set("n", "l",     lcd,   km)
  vim.keymap.set("n", "<CR>",  lcd,   km)
  vim.keymap.set("n", "c",     close, km)
  vim.keymap.set("n", "q",     close, km)
  vim.keymap.set("n", "<Esc>", close, km)
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

-- The directory half of the split path, toggled by `<C-w>sP`.
--
-- It reports the buffer's own directory relative to the project root, derived
-- from the buffer rather than from the working directory. That makes the
-- toggle mean one thing whatever 'autochdir' is set to: `FileName` drops to
-- the bare filename while this component carries the directory, so together
-- they spell the project-relative path exactly once.
local WorkDir = {
  init = function(self)
    self.icon = " "
    self.dir = vim.fs.normalize(ProjRelativeFilename())
  end,
  condition = function()
    return vim.g.heirline_directory_show
  end,
  hl = { fg = "orange", bold = true },

  flexible = ctx.priority.high,

  {
    -- evaluates to the full-length path
    provider = function(self)
      local trail = self.dir:sub(-1) == "/" and "" or "/"
      return self.icon .. self.dir .. trail
    end,
  },
  {
    -- evaluates to the shortened path
    provider = function(self)
      local dir = vim.fn.pathshorten(self.dir)
      local trail = self.dir:sub(-1) == "/" and "" or "/"
      return self.icon .. dir .. trail
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

local BufDirMismatch = {
  -- Classified in `condition`, not `init`: heirline evaluates condition
  -- first and skips init entirely when it returns false, so a state set in
  -- init is still nil by the time condition reads it.
  condition = function(self)
    self.state = cwd_state()
    return self.state ~= nil
  end,
  on_click = {
    callback = cwd_popup,
    name = "heirline_cwd_mismatch",
  },
  provider = function(self)
    return self.state == "outside" and (" " .. icons.warning .. " ") or " " .. icons.folder .. " "
  end,
  hl = function(self)
    if self.state == "outside" then
      return { fg = ctx.colors.yellow }
    end
    return { fg = ctx.colors.text_unselected }
  end,
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
    local name = vim.api.nvim_buf_get_name(0)
    if name == "" then
      return "[No Name]"
    end
    -- WorkDir is showing the project-relative directory, so render the bare
    -- filename here. Otherwise the directory appears twice under
    -- 'noautochdir', where `:.` already carries it.
    if vim.g.heirline_directory_show then
      return vim.fn.fnamemodify(name, ":t")
    end
    -- either get filename or get it relative to project:
    if vim.g.heirline_proj_relative_dir_show then
      return ProjRelativeFilename()
    end
    -- trim the path relative to the working directory.
    -- For other options, see :h filename-modifiers
    return vim.fn.fnamemodify(name, ":.")
  end,
  hl = function() return { fg = ctx.colors.text_gray } end,
}

--- Offer to put a deleted file back from the buffer still holding it.
local function missing_file_popup()
  local name = vim.api.nvim_buf_get_name(0)
  local lines = {
    " The file behind this buffer is gone from disk. ",
    " " .. vim.fn.fnamemodify(name, ":~") .. " ",
    " The buffer still holds its contents. ",
    " [W] write it back   [C]ancel ",
  }
  local width = 0
  for _, l in ipairs(lines) do
    if #l > width then width = #l end
  end

  local mouse_pos = vim.fn.getmousepos()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = buf })
  vim.api.nvim_set_option_value("bufhidden",  "wipe",  { scope = "local", buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row      = math.max(0, mouse_pos.screenrow - #lines - 2),
    col      = mouse_pos.screencol,
    width    = width,
    height   = #lines,
    style    = "minimal",
    border   = "rounded",
  })

  local function close() pcall(vim.api.nvim_win_close, win, true) end
  local function restore()
    close()
    vim.cmd("write")
  end

  local km = { buffer = buf, noremap = true, silent = true, nowait = true }
  vim.keymap.set("n", "w",     restore, km)
  vim.keymap.set("n", "<CR>",  restore, km)
  vim.keymap.set("n", "c",     close,   km)
  vim.keymap.set("n", "q",     close,   km)
  vim.keymap.set("n", "<Esc>", close,   km)
end

--- The buffer's file has been deleted from disk while the buffer stayed open.
--- Ranked ahead of the read-only and modified flags in the statusline: the
--- buffer now holds the only copy of the contents, which outranks anything
--- else those flags report.
M.MissingFileFlag = {
  condition = function()
    return vim.b.noethervim_file_missing == true
  end,
  hl = function() return { force = true, fg = ctx.colors.red, bg = ctx.flag_bg() } end,
  on_click = {
    callback = missing_file_popup,
    name = "heirline_file_missing",
  },
  provider = icons.error .. " ",
}

--- The buffer has a name but nothing at that path on disk yet, from
--- `:e newfile.txt`. The mirror of MissingFileFlag: there the file is gone
--- and the buffer is the only copy, here the file does not exist yet and
--- the buffer is still the only copy. Both say the same thing, which is
--- that closing without writing loses everything.
M.NewFileFlag = {
  condition = function()
    return vim.b.noethervim_new_file == true
       and not vim.b.noethervim_file_missing
  end,
  hl = function() return { force = true, fg = ctx.colors.diag_hint, bg = ctx.flag_bg() } end,
  on_click = {
    callback = function()
      local name = vim.api.nvim_buf_get_name(0)
      vim.notify(
        ("%s\n\nNo file at this path yet. `:w` creates it, including any\nmissing parent directories."):format(
          vim.fn.fnamemodify(name, ":~")),
        vim.log.levels.INFO, { title = "NoetherVim new file" })
    end,
    name = "heirline_new_file",
  },
  provider = " ",
}

M.ReadOnlyFlag = {
  condition = function()
    return not vim.bo.modifiable or vim.bo.readonly
  end,
  hl = function() return { force = true, fg = ctx.colors.light_red, bg = ctx.flag_bg() } end,
  provider = icons.lock .. " ",
}

M.ScratchFlag = {
  condition = function()
    return vim.api.nvim_buf_get_name(0) == "" and vim.bo.buftype == "" and vim.bo.filetype == ""
  end,
  hl = function() return { force = true, fg = ctx.colors.blue, bg = ctx.flag_bg() } end,
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
    BufDirMismatch,
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
