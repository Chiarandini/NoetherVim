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
