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
local busy_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
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
  busy_timer:start(80, 80, vim.schedule_wrap(function()
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

-- Resolve a busy-component override from the statusline registry. Walks
-- the list back-to-front so the most recently registered override wins
-- (last-write-wins). Returns nil if no override is claiming the slot.
local function resolve_busy_override()
  local ok, sl = pcall(require, "noethervim.statusline")
  if not ok or not sl.get_busy_overrides then return nil end
  local overrides = sl.get_busy_overrides()
  for i = #overrides, 1, -1 do
    local ok2, spec = pcall(overrides[i])
    if ok2 and spec then return spec end
  end
  return nil
end

M.Busy = {
  condition = function()
    return resolve_busy_override() ~= nil or (vim.bo.busy or 0) > 0
  end,
  init = function(self)
    self.override = resolve_busy_override()
  end,
  provider = function(self)
    local icon = (self.override and self.override.icon) or busy_frames[busy_frame]
    local label = self.override and self.override.label
    if label and label ~= "" then
      return icon .. " " .. label .. " "
    end
    return icon .. " "
  end,
  hl = function(self)
    if self.override and self.override.hl then return self.override.hl end
    return { fg = "orange", bold = true }
  end,
  on_click = {
    callback = function()
      local spec = resolve_busy_override()
      if spec and spec.on_click then pcall(spec.on_click) end
    end,
    name = "noethervim_busy_click",
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

-- Hidden-modified buffers warning.
--
-- A buffer that has been left in `:hide` state with unsaved edits is
-- easy to miss: it isn't shown in any window across any tabpage and the
-- bufferline doesn't surface it, yet :qa! will silently drop the changes.
-- This component walks every loaded, listed, real-file buffer and counts
-- the ones that are (a) modified and (b) not visible in any window of
-- any tabpage.  A buffer that is still open in another split or tab is
-- explicitly excluded.  Cleared automatically as soon as the buffer is
-- saved, reopened, or wiped.
local function count_hidden_modified()
  -- nvim_list_wins() returns ALL windows across every tabpage (excluding
  -- floating windows), which is exactly what we want here.  We still
  -- iterate explicit tabpages too as a belt-and-braces defense against
  -- weird edge cases where nvim_list_wins() filters something out.
  local visible = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      visible[vim.api.nvim_win_get_buf(win)] = true
    end
  end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_win_is_valid(win) then
        visible[vim.api.nvim_win_get_buf(win)] = true
      end
    end
  end
  local count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buflisted
        and vim.bo[buf].modified
        and not visible[buf]
        and vim.bo[buf].buftype == "" then
      count = count + 1
    end
  end
  return count
end

-- A muted warning chip: borrow DiagnosticWarn's foreground (every modern
-- colorscheme defines it) and let the surrounding statusline background
-- show through, so the badge feels integrated rather than pasted on.
-- A single bullet makes the count read like a notification, not a banner.
-- Float a Snacks picker filtered to hidden modified buffers.
-- Each item lets you Enter to jump back, dd/x to wipeout, w to write.
local function pick_hidden_modified()
  local visible = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      visible[vim.api.nvim_win_get_buf(win)] = true
    end
  end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_win_is_valid(win) then
        visible[vim.api.nvim_win_get_buf(win)] = true
      end
    end
  end
  local items = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buflisted
        and vim.bo[buf].modified
        and not visible[buf]
        and vim.bo[buf].buftype == "" then
      local name = vim.api.nvim_buf_get_name(buf)
      local short = name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":~:.")
      items[#items + 1] = {
        text   = short,
        file   = name ~= "" and name or nil,
        bufnr  = buf,
      }
    end
  end
  if #items == 0 then
    vim.notify("no hidden modified buffers", vim.log.levels.INFO)
    return
  end
  require("snacks").picker({
    title = "Hidden Modified Buffers",
    items = items,
    -- The on-disk file is stale (buffer is modified-but-not-written), so
    -- the default "file" previewer would show outdated content.  Render
    -- the live buffer contents into the preview pane instead.
    preview = function(pctx)
      local item = pctx.item
      if not item or not vim.api.nvim_buf_is_loaded(item.bufnr) then
        return false
      end
      local bufnr = item.bufnr
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Snacks locks preview buffers as nomodifiable to keep them from
      -- being edited.  Flip it on, paint, flip it back.
      local was_modifiable = vim.bo[pctx.buf].modifiable
      vim.bo[pctx.buf].modifiable = true
      vim.api.nvim_buf_set_lines(pctx.buf, 0, -1, false, lines)
      local ft = vim.bo[bufnr].filetype
      if ft and ft ~= "" then vim.bo[pctx.buf].filetype = ft end
      vim.bo[pctx.buf].modifiable = was_modifiable
      return true
    end,
    format = function(item)
      return {
        { "  ", "DiagnosticWarn" },
        { item.text, "Normal" },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      -- Switch to the live buffer (the modified one).  `vim.cmd.edit`
      -- on the file would re-read from disk and silently drop the
      -- unsaved changes -- we want the in-memory copy.
      if vim.api.nvim_buf_is_valid(item.bufnr) then
        vim.api.nvim_set_current_buf(item.bufnr)
      elseif item.file then
        vim.cmd.edit(vim.fn.fnameescape(item.file))
      end
    end,
  })
end

M.HiddenModified = {
  condition = function(self)
    self.count = count_hidden_modified()
    return self.count > 0
  end,
  on_click = {
    callback = function() pcall(pick_hidden_modified) end,
    name = "noethervim_hidden_modified_click",
  },
  provider = function(self)
    return string.format(" • %d unsaved ", self.count)
  end,
  -- ctx.with_mode_bg embeds the active mode's statusline bg (blue in
  -- insert, grey otherwise) into every render, so the chip blends with
  -- the bottom bar even though heirline's parent->child bg merge doesn't
  -- always reach this far.  See `ctx.mode_bg` for the rationale.
  hl = ctx.with_mode_bg(function()
    local fg = utils.get_highlight("DiagnosticWarn").fg or ctx.colors.orange or "#fabd2f"
    return { fg = fg, italic = true }
  end),
  update = { "BufModifiedSet", "BufWritePost", "BufHidden", "BufDelete", "BufWipeout", "WinEnter", "WinLeave", "TabEnter", "TabLeave", "ModeChanged" },
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
