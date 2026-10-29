-- NoetherVim toggle keymaps. Sourced by setup(), never required, so each
-- mapping here carries this file's script id.
--
-- Convention:
--   [<suffix>   enable / "on"
--   ]<suffix>   disable / "off"
--   [o<suffix>  enable option
--   ]o<suffix>  disable option

local T = require("noethervim.toggles")
local map, toggle = T.map, T.toggle
local row = require("noethervim.keymaps.rows").map

-- ──────────────────────────────────────────────────────────────
--  Option toggles  ([o<key> = on, ]o<key> = off)
-- ──────────────────────────────────────────────────────────────

toggle("oa", "<cmd>setl autochdir<cr>",      "<cmd>setl noautochdir<cr>",      "autochdir")
toggle("oN",
  function()
    vim.keymap.set({ "n", "v" }, "n", "nzz", { desc = "search forward (centered)" })
    vim.keymap.set({ "n", "v" }, "N", "Nzz", { desc = "search backward (centered)" })
  end,
  function()
    -- Restore the original direction-normalizing expr mappings from keymaps.lua
    vim.keymap.set({ "n", "v" }, "n",
      function() return vim.v.searchforward == 1 and "n" or "N" end,
      { expr = true, silent = true, desc = "search forward" })
    vim.keymap.set({ "n", "v" }, "N",
      function() return vim.v.searchforward == 1 and "N" or "n" end,
      { expr = true, silent = true, desc = "search backward" })
  end,
  "centered n/N")

toggle("o<c-i>",
  function() vim.lsp.inlay_hint.enable(true) end,
  function() vim.lsp.inlay_hint.enable(false) end,
  "inlay hints")

toggle("o<c-t>",
  function() require("tint").enable() end,
  function() require("tint").disable() end,
  "tint", { owner = "tint.nvim" })

-- Tidy whitespace trimmer (tidy.nvim only exposes .toggle())
toggle("oD",
  function()
    local tidy = require("tidy")
    if not tidy.opts.enabled_on_save then tidy.toggle() end
  end,
  function()
    local tidy = require("tidy")
    if tidy.opts.enabled_on_save then tidy.toggle() end
  end,
  "tidy whitespace (Dirty)", { owner = "tidy.nvim" })

-- Deadcolumn fading guide -- [oG enable, ]oG disable.
-- State persisted to stdpath("state")/noethervim/deadcolumn;
-- deadcolumn.lua reads this on startup to skip setup() when disabled.
local dc_state_file = vim.fn.stdpath("state") .. "/noethervim/deadcolumn"
vim.fn.mkdir(vim.fs.dirname(dc_state_file), "p")

toggle("oG",
  function()
    local dc = require("deadcolumn")
    dc.setup(dc.configs.opts)
    local ftw = dc.configs.opts.extra.follow_tw
    if ftw then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].textwidth ~= 0 then
          vim.wo[win].colorcolumn = ftw
        end
      end
    end
    vim.fn.writefile({ "1" }, dc_state_file)
  end,
  function()
    vim.api.nvim_create_augroup("deadcolumn", { clear = true })
    -- follow_tw autocmds are created by deadcolumn without a group;
    -- remove them by desc so they don't re-set colorcolumn on BufEnter.
    for _, ev in ipairs({ "BufEnter", "OptionSet" }) do
      for _, au in ipairs(vim.api.nvim_get_autocmds({ event = ev })) do
        if au.desc == "Set colorcolumn according to textwidth." then
          vim.api.nvim_del_autocmd(au.id)
        end
      end
    end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      vim.wo[win].colorcolumn = ""
      vim.wo[win].winhl = vim.wo[win].winhl:gsub("ColorColumn:[^,]*", "")
        :gsub(",+", ","):gsub("^,", ""):gsub(",$", "")
    end
    vim.fn.writefile({ "0" }, dc_state_file)
  end,
  "deadcolumn (Guide)", { owner = "deadcolumn.nvim" })

-- :LspStart / :LspStop were removed on Nvim 0.12+ (superseded by built-in :Lsp).
-- Bare :lsp enable resolves to all configs matching current buffer's filetype;
-- bare :lsp disable resolves to all configs attached to current buffer.
toggle("oL", "<cmd>lsp enable<cr>", "<cmd>lsp disable<cr>", "lsp")

-- Abolish auto-correct in code regions
-- Default behavior: corrections fire only in writing buffers and inside
-- comments / @spell regions of code buffers. [oA forces unconditional
-- expansion in the current buffer; ]oA returns to context-gated.
toggle("oA",
  function() vim.b.noethervim_abolish_force = true end,
  function() vim.b.noethervim_abolish_force = nil end,
  "abolish auto-correct in code")

-- Inline math rendering (Snacks.image; the markdown bundle turns it on).
--
-- `[om` renders math in the current buffer, which is how a tex or typst
-- buffer opts in: the markdown bundle claims markdown and leaves other
-- filetypes to their own devices. `]om` stops math rendering everywhere,
-- for a document where typesetting each equation costs more than reading
-- the source does.
--
-- Off is global because Snacks tracks no per-buffer switch for it, and the
-- flag the discovery pass reads (`math.enabled`) is one value for the
-- session. Clearing the extmarks takes the images off the screen at once;
-- the next pass over each buffer drops the placements behind them.
local function image_math(on)
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.image or not snacks.image.config.enabled then
    vim.notify("inline math needs the markdown bundle", vim.log.levels.WARN)
    return
  end
  snacks.image.config.math.enabled = on
  if not on then
    local ns = vim.api.nvim_create_namespace("snacks.image")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      end
    end
  elseif vim.b.noethervim_image_scoped or not vim.b.snacks_image_attached then
    vim.b.noethervim_image_scoped = nil
    vim.b.snacks_image_attached = nil
    -- A real buffer number, not 0: Snacks names the buffer's augroup after
    -- whatever it is handed, so 0 would build a group nothing else can find.
    require("snacks.image.doc").attach(vim.api.nvim_get_current_buf())
  else
    -- Already attached, so nothing is scheduled to redraw it. WinScrolled is
    -- what the inline renderer listens on that costs nothing to fake.
    vim.api.nvim_exec_autocmds("WinScrolled", { modeline = false })
  end
  T._notify("inline math " .. (on and "enabled" or "disabled"))
end

row("n", "[om", function() image_math(true)  end, { desc = "enable inline math" })
row("n", "]om", function() image_math(false) end, { desc = "disable inline math" })

-- Blink.cmp completion on/off
vim.g.blink_toggle = true
local function toggle_cmp(bool)
  vim.g.blink_toggle = bool
  T._notify("completion " .. (bool and "enabled" or "disabled"))
end
row("n", "[oC", function() toggle_cmp(true)  end, { desc = "enable completion", owner = "blink.cmp" })
row("n", "]oC", function() toggle_cmp(false) end, { desc = "disable completion", owner = "blink.cmp" })

-- Quickfix / Trouble navigation (context-aware)
-- When Trouble is open, ]q/[q/]Q/[Q navigate its items.
-- When Trouble is closed, they navigate the native quickfix list, as
-- Neovim's own ]q/[q/]Q/[Q do.
local function trouble_or_qf(trouble_fn, qf_cmd)
  return function()
    local ok, trouble = pcall(require, "trouble")
    if ok and trouble.is_open() then
      trouble_fn(trouble)
    else
      local success, err = pcall(vim.cmd, qf_cmd)
      if not success and err then
        vim.notify(err:gsub("^.*:%s*", ""), vim.log.levels.WARN)
      end
    end
  end
end

row("n", "]q", trouble_or_qf(
  function(t) t.next({ jump = true }) end, "cnext"
), { desc = "next quickfix/Trouble item", set = "remaps" })

row("n", "[q", trouble_or_qf(
  function(t) t.prev({ jump = true }) end, "cprev"
), { desc = "prev quickfix/Trouble item", set = "remaps" })

row("n", "]Q", trouble_or_qf(
  function(t) t.last({ jump = true }) end, "clast"
), { desc = "last quickfix/Trouble item", set = "remaps" })

row("n", "[Q", trouble_or_qf(
  function(t) t.first({ jump = true }) end, "cfirst"
), { desc = "first quickfix/Trouble item", set = "remaps" })

-- Unimpaired-style option toggles
map("[ob", "<cmd>set background=light<cr>",    "light background")
map("]ob", "<cmd>set background=dark<cr>",     "dark background")
map("[oc", "<cmd>setlocal cursorline<cr>",     "cursorline")
map("]oc", "<cmd>setlocal nocursorline<cr>",   "no cursorline")
map("[od", "<cmd>diffthis<cr>",                "diffthis")
map("]od", "<cmd>diffoff<cr>",                 "diffoff")
map("[oh", "<cmd>set hlsearch<cr>",            "hlsearch")
map("]oh", "<cmd>set nohlsearch<cr>",          "no hlsearch")
map("[oi", "<cmd>set ignorecase<cr>",          "ignorecase")
map("]oi", "<cmd>set noignorecase<cr>",        "no ignorecase")
map("[ol", "<cmd>setlocal list<cr>",           "show trailing chars")
map("]ol", "<cmd>setlocal nolist<cr>",         "hide trailing chars")
map("[on", "<cmd>setlocal number<cr>",         "line numbers")
map("]on", "<cmd>setlocal nonumber<cr>",       "no line numbers")
map("[or", "<cmd>setlocal relativenumber<cr>", "relative numbers")
map("]or", "<cmd>setlocal norelativenumber<cr>","no relative numbers")
map("[os", "<cmd>setlocal spell<cr>",          "spell")
map("]os", "<cmd>setlocal nospell<cr>",        "no spell")
map("[oS", "<cmd>setlocal scrollbind<cr>",     "scrollbind")
map("]oS", "<cmd>setlocal noscrollbind<cr>",   "no scrollbind")
map("[ot", "<cmd>setlocal colorcolumn=+1<cr>", "colorcolumn")
map("]ot", "<cmd>setlocal colorcolumn=<cr>",   "no colorcolumn")
map("[ou", "<cmd>setlocal cursorcolumn<cr>",   "cursorcolumn")
map("]ou", "<cmd>setlocal nocursorcolumn<cr>", "no cursorcolumn")
map("[ov", "<cmd>set virtualedit+=all<cr>",    "virtualedit")
map("]ov", "<cmd>set virtualedit-=all<cr>",    "no virtualedit")
map("[ow", "<cmd>setlocal wrap<cr>",           "wrap")
map("]ow", "<cmd>setlocal nowrap<cr>",         "no wrap")
-- `setlocal`, like every other window-local toggle here. With plain `:set`
-- these also wrote the global default, so turning the crosshair on in one
-- window handed it to every window opened afterwards -- which reads as the
-- toggle having leaked into an unrelated buffer.
map("[ox", "<cmd>setlocal cursorline cursorcolumn<cr>",    "crosshair")
map("]ox", "<cmd>setlocal nocursorline nocursorcolumn<cr>","no crosshair")

-- Window auto-width animation
map("[oW", '<cmd>WindowsEnableAutowidth<cr>',  "animated windows", nil, { owner = "windows.nvim" })
map("]oW", '<cmd>WindowsDisableAutowidth<cr>', "static windows",   nil, { owner = "windows.nvim" })

-- Treesitter
map("[oT", function() vim.treesitter.start(0) end, "treesitter enable")
map("]oT", function() vim.treesitter.stop(0)  end, "treesitter disable")

-- ──────────────────────────────────────────────────────────────
--  Directional navigation  ([x = prev, ]x = next)
-- ──────────────────────────────────────────────────────────────

-- Tabs
map("[t", "gT", "prev tab", false, { set = "remaps" })
map("]t", "gt", "next tab", false, { set = "remaps" })
map(">t", "<cmd>+tabmove<cr>", "move tab right", false, { set = "remaps" })
map("<t", "<cmd>-tabmove<cr>", "move tab left",  false, { set = "remaps" })

-- Buffers
map("[b", "<cmd>bp<cr>", "prev buffer", false, { set = "remaps" })
map("]b", "<cmd>bn<cr>", "next buffer", false, { set = "remaps" })

-- DAP virtual text
toggle("oV",
  "<cmd>DapVirtualTextEnable<cr>",
  "<cmd>DapVirtualTextDisable<cr>",
  "debug virtual text", { owner = "nvim-dap-virtual-text" })

-- ──────────────────────────────────────────────────────────────
--  Unimpaired-style line operations  ([e/]e, [<Space>/]<Space>)
--  Ported from tpope/vim-unimpaired (Vimscript)
-- ──────────────────────────────────────────────────────────────

vim.cmd([[
function! s:ExecMove(cmd) abort
  let old_fdm = &foldmethod
  if old_fdm !=# 'manual' | let &foldmethod = 'manual' | endif
  normal! m`
  silent! exe a:cmd
  norm! ``
  if old_fdm !=# 'manual' | let &foldmethod = old_fdm | endif
endfunction

function! s:MoveUp(count) abort
  call s:ExecMove('move--'.a:count)
endfunction
function! s:MoveDown(count) abort
  call s:ExecMove('move+'.a:count)
endfunction
function! s:MoveSelUp(c) abort
  call s:ExecMove("'<,'>move'<--".a:c)
endfunction
function! s:MoveSelDown(c) abort
  call s:ExecMove("'<,'>move'>+".a:c)
endfunction

nnoremap <silent> <Plug>(nv-move-up)           :<C-U>call <SID>MoveUp(v:count1)<CR>
nnoremap <silent> <Plug>(nv-move-down)         :<C-U>call <SID>MoveDown(v:count1)<CR>
noremap  <silent> <Plug>(nv-move-sel-up)       :<C-U>call <SID>MoveSelUp(v:count1)<CR>
noremap  <silent> <Plug>(nv-move-sel-down)     :<C-U>call <SID>MoveSelDown(v:count1)<CR>

function! s:BlankUp() abort
  return 'put!=repeat(nr2char(10),v:count1)|silent '']+'
endfunction
function! s:BlankDown() abort
  return 'put =repeat(nr2char(10),v:count1)|silent ''[-'
endfunction

nnoremap <silent> <Plug>(nv-blank-up)   :<C-U>exe <SID>BlankUp()<CR>
nnoremap <silent> <Plug>(nv-blank-down) :<C-U>exe <SID>BlankDown()<CR>
]])

row("n", "[e", "<Plug>(nv-move-up)",       { desc = "move line up" })
row("n", "]e", "<Plug>(nv-move-down)",     { desc = "move line down" })
row("x", "[e", "<Plug>(nv-move-sel-up)",   { desc = "move selection up" })
row("x", "]e", "<Plug>(nv-move-sel-down)", { desc = "move selection down" })
row("n", "[<Space>", "<Plug>(nv-blank-up)",   { desc = "blank line above", set = "remaps" })
row("n", "]<Space>", "<Plug>(nv-blank-down)", { desc = "blank line below", set = "remaps" })
