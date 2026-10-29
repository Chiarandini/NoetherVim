-- Filetype profiles: writing and code. Sourced by setup(), never required.
--
-- Writing buffers (tex, markdown, gitcommit, ...) get wrap, linebreak,
-- spell, conceallevel=2 and formatoptions+t, with list chars hidden. Code
-- buffers get list chars, and spell when spell_in_code is on in
-- lua/user/config.lua (scoped to comments and strings by treesitter's
-- @spell captures). Filetypes the profiles leave alone, and how to change
-- the classes: profiles/init.lua.
--
-- Every write goes through default.setlocal, which skips a value that is
-- yours (set by a file of yours, a modeline, a FileType autocmd, or in the
-- running session) and writes with :setlocal semantics. The OptionSet
-- observer below records the values provenance cannot attribute: a typed
-- :setlocal, a toggle, a timer.
--
-- Applied on FileType and again on BufWinEnter, through win_findbuf rather
-- than the current window: FileType fires for hidden scratch buffers too
-- (mason, lazydev, treesitter probes), and a buffer shown later in another
-- window, or after a float wrote its window info, gets its values back.

local default  = require("noethervim.default")
local profiles = require("noethervim.profiles")

local spell_in_code = require("noethervim.config").get().spell_in_code == true
local LAYOUT = { layout = true }

-- Wrapped-line marker. It lives in the number column rather than in
-- 'showbreak' because 'showbreak' occupies a text cell, which pushes every
-- continuation line one column right of the text it continues. v:virtnum
-- is >0 on wrapped rows and <0 on virtual-text lines, which get a blank.
-- %C keeps the fold column working for anyone who turns 'foldcolumn' on.
--
-- A 'statuscolumn' is drawn whether or not 'number' is set, so the number
-- half has to check both options itself; otherwise `]on` would appear to
-- do nothing in a writing buffer. With both off the column keeps only the
-- wrap marker, which is the point of it.
--
-- Both strings put the sign item inside a click region. A sign has no click
-- callback of its own, and `%@...@` in a 'statuscolumn' is the only hook
-- Neovim offers, which is why the column is set even where there is no wrap
-- marker to draw. What a click does lives in util/gutter.lua.
local sign_click = "%@v:lua.require'noethervim.util.gutter'.on_click@%s%X"

local wrap_statuscolumn =
  "%C" .. sign_click
  .. [[%=%{v:virtnum > 0 ? "↳" : (v:virtnum < 0 ? "" : ]]
  .. [[(!&number && !&relativenumber ? "" : ]]
  .. [[(&relativenumber && v:relnum > 0 ? v:relnum : (&number ? v:lnum : v:relnum))))} ]]

-- The unwrapped half, where there are no continuation rows to mark. `%l` is
-- the number column itself rather than a reimplementation of it: it renders
-- whatever 'number' and 'relativenumber' ask for and carries LineNrAbove,
-- LineNrBelow and CursorLineNr on its own, so this draws the same cells the
-- native column it replaces would have drawn.
local code_statuscolumn = "%C" .. sign_click .. "%=%l "

--- Keep the gutter in step with 'wrap'. The marker belongs to the option,
--- not to the filetype: a code buffer someone ran `[ow` in has exactly the
--- same ambiguity a wrapped prose buffer does.
---
--- Wrap off swaps in the marker-free half rather than clearing the option,
--- because the sign column's click region rides along with it.
---
--- `writing` also hands 'list' over. A line that runs off the right edge is
--- marked by 'listchars' `extends`, which only draws while 'list' is on, and
--- the writing profile turns 'list' off to keep tabs and trailing space out
--- of prose. Prose that scrolls sideways has left the profile's assumption,
--- so it gets the code layout's edge markers back.
---@param buf integer
---@param win integer the window whose 'wrap' decides
---@param writing boolean
local function gutter(buf, win, writing)
  local wrap = vim.wo[win].wrap
  default.setlocal(buf, "statuscolumn", wrap and wrap_statuscolumn or code_statuscolumn, { win = win })
  if writing then default.setlocal(buf, "list", not wrap, { win = win }) end
end

--- The non-floating windows showing `buf`.
local function windows(buf)
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.fn.win_findbuf(buf))
end

--- Whether a buffer key is free of the distro's `ft` rows, which are mapped
--- before this file's FileType autocmd runs: a filetype's own key (the latex
--- bundle's accent-aware zg) is more specific than the profile's.
local function row_free(buf, mode, lhs)
  return not (vim.b[buf].noethervim_rows or {})[mode .. " " .. vim.keycode(lhs)]
end

local function writing_keys(buf)
  if vim.b[buf].noethervim_writing_keymap then return end
  -- `<Cmd>` runs the fix without leaving insert mode. `<c-g>u` either side
  -- keeps the correction its own undo step.
  if row_free(buf, "i", "<c-l>") then
    vim.keymap.set("i", "<c-l>",
      "<c-g>u<Cmd>lua require('noethervim.util.spell').fix_previous()<CR><c-g>u",
      { buffer = buf, silent = true, desc = "fix spelling" })
  end
  -- Adding a word also adds the forms you will go on to write; see
  -- util/spell.lua for which, and why those.
  if row_free(buf, "n", "zg") then
    vim.keymap.set("n", "zg", function()
      require("noethervim.util.spell").add_under_cursor(false)
    end, { buffer = buf, desc = "add word to spellfile (with variants)" })
  end
  if row_free(buf, "n", "zG") then
    vim.keymap.set("n", "zG", function()
      require("noethervim.util.spell").add_under_cursor(true)
    end, { buffer = buf, desc = "add word for this session (with variants)" })
  end
  vim.b[buf].noethervim_writing_keymap = true
end

local function apply_writing(buf)
  local fo = vim.bo[buf].formatoptions
  if not fo:find("t", 1, true) then default.setlocal(buf, "formatoptions", fo .. "t") end
  writing_keys(buf)
  -- wrap and linebreak are layout: a global of yours does not reach prose
  -- (wrapping is what makes it readable); set them per filetype instead.
  default.setlocal(buf, "wrap", true, LAYOUT)
  default.setlocal(buf, "linebreak", true, LAYOUT)
  default.setlocal(buf, "conceallevel", 2)
  default.setlocal(buf, "spell", true)
  for _, win in ipairs(windows(buf)) do gutter(buf, win, true) end
end

local function apply_code(buf)
  default.setlocal(buf, "list", true)
  for _, win in ipairs(windows(buf)) do gutter(buf, win, false) end
  if spell_in_code then default.setlocal(buf, "spell", true) end
end

local group = vim.api.nvim_create_augroup("noethervim.profiles", { clear = true })

-- Completion waits to be asked in conservative buffers; blink.cmp reads the
-- flag, and any other engine may. Kept when something else set it first.
local auto_conservative = {} ---@type table<integer, true>

vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group    = group,
  callback = function(ev)
    if ev.event == "FileType" and vim.bo[ev.buf].buftype == ""
        and (vim.b[ev.buf].noethervim_conservative == nil or auto_conservative[ev.buf]) then
      vim.b[ev.buf].noethervim_conservative = profiles.conservative(ev.buf)
      auto_conservative[ev.buf] = true
    end
    local profile = profiles.of(ev.buf)
    if profile == "writing" then
      apply_writing(ev.buf)
    elseif profile == "code" then
      apply_code(ev.buf)
    end
  end,
})

-- The claim observer. OptionSet fires for writes outside autocmds: typed
-- :set and :setlocal, keymaps (your own and the distro's toggles, which are
-- yours to press), modelines, timers. Floats are skipped: a picker's
-- preview window writing into the previewed buffer is not a choice of
-- yours.
local MANAGED = { "wrap", "linebreak", "conceallevel", "spell", "list", "statuscolumn", "formatoptions" }

vim.api.nvim_create_autocmd("OptionSet", {
  group    = group,
  pattern  = MANAGED,
  callback = function(ev)
    local cmd = vim.v.option_command
    if default.writing or cmd == "setglobal" then return end
    if vim.api.nvim_win_get_config(0).relative ~= "" then return end
    default.claim(vim.api.nvim_get_current_buf(), ev.match, ":" .. cmd .. " in this buffer")
  end,
})

-- `[ow` / `]ow` flip 'wrap' between profile applications, so the gutter
-- follows the option rather than only the filetype.
vim.api.nvim_create_autocmd("OptionSet", {
  group    = group,
  pattern  = "wrap",
  callback = function()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    local profile = profiles.of(buf)
    if profile then gutter(buf, win, profile == "writing") end
  end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
  group    = group,
  callback = function(ev)
    default.forget(ev.buf)
    auto_conservative[ev.buf] = nil
  end,
})
