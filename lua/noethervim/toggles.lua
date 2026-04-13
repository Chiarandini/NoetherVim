-- NoetherVim toggle keymaps
-- Convention:
--   [<suffix>   enable / "on"
--   ]<suffix>   disable / "off"
--   [o<suffix>  enable option
--   ]o<suffix>  disable option
--
-- toggle(lhs, enable_rhs, disable_rhs, desc)  → maps [lhs and ]lhs
-- map(lhs, rhs, desc)                         → single directional map

local function TOGGLE_PRINT(text)
  vim.cmd('echom "' .. text .. '"')
end

local function map(lhs, rhs, desc, echo)
  local descr = desc or ""
  if type(rhs) == "string" then
    if echo ~= false then
      vim.keymap.set("n", lhs,
        rhs .. '<cmd>lua vim.cmd("echom \\"' .. descr .. '\\"")<cr>',
        { desc = descr })
    else
      vim.keymap.set("n", lhs, rhs, { desc = descr })
    end
  elseif type(rhs) == "function" then
    if echo ~= false then
      vim.keymap.set("n", lhs, function()
        TOGGLE_PRINT(descr)
        rhs()
      end, { desc = descr })
    else
      vim.keymap.set("n", lhs, rhs, { desc = descr })
    end
  end
end

local function toggle(lhs, enable, disable, desc)
  map("[" .. lhs, enable,  "enabling: "  .. desc)
  map("]" .. lhs, disable, "disabling: " .. desc)
end

-- ──────────────────────────────────────────────────────────────
--  Option toggles  ([o<key> = on, ]o<key> = off)
-- ──────────────────────────────────────────────────────────────

toggle("oa", "<cmd>setl autochdir<cr>",      "<cmd>setl noautochdir<cr>",      "autochdir")
toggle("oN",
  "<cmd>nnoremap n nzz<cr><cmd>nnoremap N Nzz<cr>",
  "<cmd>nnoremap n n<cr><cmd>nnoremap N N<cr>",
  "centered n/N")

toggle("o<c-i>",
  function() vim.lsp.inlay_hint.enable(true) end,
  function() vim.lsp.inlay_hint.enable(false) end,
  "inlay hints")

toggle("o<c-t>",
  function() require("tint").enable() end,
  function() require("tint").disable() end,
  "tint")

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
  "tidy whitespace (Dirty)")

-- Deadcolumn fading guide — [oG enable, ]oG disable.
-- State persisted to stdpath("state")/noethervim_deadcolumn;
-- deadcolumn.lua reads this on startup to skip setup() when disabled.
local dc_state_file = vim.fn.stdpath("state") .. "/noethervim_deadcolumn"

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
  "deadcolumn (Guide)")

toggle("oL", "<cmd>LspStart<cr>", "<cmd>LspStop<cr>", "lsp")

-- Blink.cmp completion on/off
vim.g.blink_toggle = true
local function toggle_cmp(bool)
  vim.g.blink_toggle = bool
  vim.notify("completion " .. (bool and "enabled" or "disabled"), vim.log.levels.INFO)
end
vim.keymap.set("n", "[C", function() toggle_cmp(true)  end, { desc = "enable completion" })
vim.keymap.set("n", "]C", function() toggle_cmp(false) end, { desc = "disable completion" })

-- Quickfix navigation
map("[Q", "<cmd>cfirst<cr>", "quickfix first", false)
map("]Q", "<cmd>clast<cr>",  "quickfix last",  false)

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
map("[ot", "<cmd>set colorcolumn=+1<cr>",      "colorcolumn")
map("]ot", "<cmd>set colorcolumn=<cr>",        "no colorcolumn")
map("[ou", "<cmd>setlocal cursorcolumn<cr>",   "cursorcolumn")
map("]ou", "<cmd>setlocal nocursorcolumn<cr>", "no cursorcolumn")
map("[ov", "<cmd>set virtualedit+=all<cr>",    "virtualedit")
map("]ov", "<cmd>set virtualedit-=all<cr>",    "no virtualedit")
map("[ow", "<cmd>setlocal wrap<cr>",           "wrap")
map("]ow", "<cmd>setlocal nowrap<cr>",         "no wrap")
map("[ox", "<cmd>set cursorline cursorcolumn<cr>",    "crosshair")
map("]ox", "<cmd>set nocursorline nocursorcolumn<cr>","no crosshair")

-- Illuminate (variable highlight)
map("[oI", "<cmd>IlluminateResumeBuf<cr>",  "illuminate on")
map("]oI", "<cmd>IlluminatePauseBuf<cr>",   "illuminate off")

-- Window auto-width animation
map("[oW", '<cmd>WindowsEnableAutowidth<cr>',  "animated windows")
map("]oW", '<cmd>WindowsDisableAutowidth<cr>', "static windows")

-- Treesitter
map("[oT", function() vim.treesitter.start(0) end, "treesitter enable")
map("]oT", function() vim.treesitter.stop(0)  end, "treesitter disable")

-- ──────────────────────────────────────────────────────────────
--  Directional navigation  ([x = prev, ]x = next)
-- ──────────────────────────────────────────────────────────────

-- Tabs
map("[t", "gT", "prev tab", false)
map("]t", "gt", "next tab", false)
map(">t", "<cmd>+tabmove<cr>", "move tab right", false)
map("<t", "<cmd>-tabmove<cr>", "move tab left",  false)

-- Buffers
map("[b", "<cmd>bp<cr>", "prev buffer", false)
map("]b", "<cmd>bn<cr>", "next buffer", false)

-- DAP virtual text
toggle("V",
  "<cmd>DapVirtualTextEnable<cr>",
  "<cmd>DapVirtualTextDisable<cr>",
  "debug virtual text")

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

nmap [e <Plug>(nv-move-up)
nmap ]e <Plug>(nv-move-down)
xmap [e <Plug>(nv-move-sel-up)
xmap ]e <Plug>(nv-move-sel-down)
nmap [<Space> <Plug>(nv-blank-up)
nmap ]<Space> <Plug>(nv-blank-down)
]])
