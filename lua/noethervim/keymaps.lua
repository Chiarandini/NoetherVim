-- NoetherVim core keymaps
-- Philosophy:
--   SearchLeader  fuzzy navigation/search (default: <Space>, set vim.g.mapsearchleader)
--   <Leader>      global actions
--   <LocalLeader> filetype-specific actions
--   <C-w>         all window navigation/manipulation
--   [x / ]x       prev/next directional navigation
--   [ox / ]ox     toggle option on/off

-- ──────────────────────────────────────────────────────────────
--  Insert mode
-- ──────────────────────────────────────────────────────────────

vim.keymap.set("i", "<M-BS>",  "<c-w>",      { desc = "delete word backward" })
vim.keymap.set("i", "<D-BS>",  "<c-o>dd",    { desc = "delete line" })
vim.keymap.set("i", "<c-w>",   "<nop>",      { desc = "disable.. too many windows accidentally close" })
vim.keymap.set("i", "<C-a>",   "<Esc>ggVG",  { desc = "select all" })
vim.keymap.set("i", "<C-v>",   '<Esc>"*pa',  { desc = "paste from clipboard" })
vim.keymap.set("i", "<C-p>",   "<nop>",      { desc = "disabled" })
vim.keymap.set("i", "<C-s>",   "<nop>",      { desc = "disabled" })
vim.keymap.set("i", "<C-=>",   "<C-r>=",     { desc = "expression register" })

-- ──────────────────────────────────────────────────────────────
--  Normal mode -- general
-- ──────────────────────────────────────────────────────────────

-- Hybrid j/k: visual-line for small hops (natural under wrap), logical +
-- jumplist mark for big hops (>5) so <C-o>/<C-i> recover the jump.
local function vline_move(key)
  local n = vim.v.count
  if n > 5 then
    return "m'" .. n .. key       -- set jump mark, then logical-line move
  elseif n > 0 then
    return n .. "g" .. key         -- counted visual-line move
  else
    return "g" .. key              -- single visual-line hop
  end
end
vim.keymap.set("n", "j", function() return vline_move("j") end,
  { expr = true, desc = "visual-line down (jumplist for >5)" })
vim.keymap.set("n", "k", function() return vline_move("k") end,
  { expr = true, desc = "visual-line up (jumplist for >5)" })

-- Scroll view without moving cursor
vim.keymap.set("n", "zv", "zz10<c-e>", { desc = "scroll view down" })
vim.keymap.set("n", "zx", "zz10<c-y>", { desc = "scroll view up" })

-- s: s does not pollute unnamed register;
vim.keymap.set("n", "s",  '"_s',  { desc = "substitute without register" })

-- S: triggers global substitution
vim.keymap.set("n", "S",  ":%s/", { desc = "global search/replace" })

-- Consistent n/N direction regardless of search direction
vim.keymap.set({ "n", "v" }, "n",
  function() return vim.v.searchforward == 1 and "n" or "N" end,
  { expr = true, silent = true, desc = "search forward" })
vim.keymap.set({ "n", "v" }, "N",
  function() return vim.v.searchforward == 1 and "N" or "n" end,
  { expr = true, silent = true, desc = "search backward" })

-- ; as :
vim.keymap.set("n", ";", ":", { desc = "command-line" })

-- <C-g> shows extended file info
vim.keymap.set("n", "<c-g>", "g<c-g>", { desc = "file info" })

-- ──────────────────────────────────────────────────────────────
--  Normal mode -- window / tab management  (<C-w> namespace)
-- ──────────────────────────────────────────────────────────────

-- <c-h/j/k/l>: shorthand for <c-w>h/j/k/l window navigation
vim.keymap.set("n", "<c-h>", "<c-w>h", { desc = "window left" })
vim.keymap.set("n", "<c-j>", "<c-w>j", { desc = "window down" })
vim.keymap.set("n", "<c-k>", "<c-w>k", { desc = "window up" })
vim.keymap.set("n", "<c-l>", "<c-w>l", { desc = "window right" })

vim.keymap.set("n", "<c-w><a-h>", "<cmd>tabm -<cr>", { desc = "move tab left" })
vim.keymap.set("n", "<c-w><a-l>", "<cmd>tabm +<cr>", { desc = "move tab right" })
vim.keymap.set("n", "<c-w><c-q>", "<cmd>copen<cr>",  { desc = "open quickfix" })

-- Toggle quickfix window (SearchLeader+q)
local SearchLeader = require("noethervim.util").search_leader
vim.keymap.set("n", SearchLeader .. "q", function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.fn.getwinvar(win, "&buftype") == "quickfix" then
      vim.cmd("cclose")
      return
    end
  end
  vim.cmd("copen")
end, { desc = "[q]uickfix toggle" })
-- <c-w>u: set in commands.lua (show unsaved buffers)

-- Resize splits with arrow keys
vim.keymap.set("n", "<up>",    "<cmd>resize +2<cr>",          { desc = "taller" })
vim.keymap.set("n", "<down>",  "<cmd>resize -2<cr>",          { desc = "shorter" })
vim.keymap.set("n", "<left>",  "<cmd>vertical resize +2<cr>", { desc = "wider" })
vim.keymap.set("n", "<right>", "<cmd>vertical resize -2<cr>", { desc = "narrower" })

-- Quick splits (unnamed scratch buffers -- save with :w <name> if needed)
local function split_scratch(cmd)
  vim.cmd(cmd)
  vim.cmd("enew")
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
end
vim.keymap.set("n", "|", function() split_scratch("vs") end,  { desc = "vertical split scratch" })
vim.keymap.set("n", "+", "<cmd>tabe<cr>",                      { desc = "new tab" })
vim.keymap.set("n", "_", function() split_scratch("sp") end,  { desc = "horizontal split scratch" })

-- ──────────────────────────────────────────────────────────────
--  Normal mode -- buffer management  (Z prefix)
-- ──────────────────────────────────────────────────────────────

vim.keymap.set("n", "ZA", "<cmd>qa<cr>",         { desc = "quit all" })
vim.keymap.set("n", "ZF", "<cmd>q!<cr>",         { desc = "quit force" })
vim.keymap.set("n", "ZK", "<cmd>qa!<cr>",         { desc = "quit all! (kill nvim)" })
vim.keymap.set("n", "ZB", "<cmd>bdelete<cr>",    { desc = "delete buffer" })
vim.keymap.set("n", "ZG", "<cmd>bdelete!<cr>",   { desc = "delete buffer force" })
vim.keymap.set("n", "ZD", function()
  for _, buf in pairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf)
      and vim.api.nvim_buf_get_name(buf) == ""
      and vim.bo[buf].buftype == "" then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end, { desc = "delete scratch buffers" })

-- ──────────────────────────────────────────────────────────────
--  Normal mode -- cursor / search utilities
-- ──────────────────────────────────────────────────────────────

-- Highlight all instances of word under cursor (count + jump to next occurrence)
vim.keymap.set("n", "-",
  ":let save_cursor=getcurpos()|let @/ = '\\<'.expand('<cword>').'\\>'|set hlsearch<CR>" ..
  "w?<CR>:%s///gn<CR>:call setpos('.', save_cursor)<CR>",
  { silent = true, desc = "highlight word under cursor" })

-- Path/file utilities (cp, cm, gp) removed from core -- they shadow Vim's
-- c+p / c+m / g+p operator sequences.  See templates/user/keymaps.example.lua
-- or add them to your lua/user/keymaps.lua

-- ]f / [f: next/previous file in the same directory (alphabetical order)
do
  local function navigate_file(dir)
    local current = vim.fn.expand("%:p")
    local folder  = vim.fn.expand("%:p:h")
    local files   = vim.tbl_filter(
      function(f) return vim.fn.filereadable(f) == 1 end,
      vim.fn.glob(folder .. "/*", false, true)
    )
    table.sort(files)
    for i, f in ipairs(files) do
      if f == current then
        local target = files[((i - 1 + dir) % #files) + 1]
        vim.cmd("edit " .. vim.fn.fnameescape(target))
        return
      end
    end
  end
  vim.keymap.set("n", "]f", function() navigate_file( 1) end, { desc = "next file in directory" })
  vim.keymap.set("n", "[f", function() navigate_file(-1) end, { desc = "prev file in directory" })
end

-- ──────────────────────────────────────────────────────────────
--  Normal mode -- disable overlapping ghost keys
-- ──────────────────────────────────────────────────────────────

-- Prevent ys/yS from interfering with ySS/yss
vim.keymap.set("n", "yS",  "", { desc = "disabled (use ySS)" })
vim.keymap.set("n", "ys",  "", { desc = "disabled (use yss)" })
vim.keymap.set("n", "yss", "", { desc = "disabled" })

-- Toggle comment (Neovim 0.10+ builtin gc/gcc)
vim.keymap.set("n", "<C-/>", "gcc", { remap = true, desc = "toggle comment" })
vim.keymap.set("v", "<C-/>", "gc",  { remap = true, desc = "toggle comment" })
vim.keymap.set("i", "<C-/>", "<Esc>gcc", { remap = true, desc = "toggle comment" })

-- Comment-yank-paste: comment original lines, paste uncommented copy below
local function comment_yank_paste()
  local win = vim.api.nvim_get_current_win()
  local cur = vim.api.nvim_win_get_cursor(win)
  local vstart = vim.fn.getpos("v")[2]
  local current_line = vim.fn.line(".")
  local set_cur = vim.api.nvim_win_set_cursor
  if vstart == current_line then
    vim.cmd.yank()
    vim.cmd("normal gcc")
    vim.cmd.put()
    set_cur(win, { cur[1] + 1, cur[2] })
  else
    if vstart < current_line then
      vim.cmd(":" .. vstart .. "," .. current_line .. "y")
      vim.cmd.put()
      set_cur(win, { vim.fn.line("."), cur[2] })
    else
      vim.cmd(":" .. current_line .. "," .. vstart .. "y")
      set_cur(win, { vstart, cur[2] })
      vim.cmd.put()
      set_cur(win, { vim.fn.line("."), cur[2] })
    end
    vim.cmd("normal! gvgc")
  end
end
vim.keymap.set({ "n", "v", "x" }, "<C-S-r>", comment_yank_paste, { desc = "comment and paste text" })

-- ──────────────────────────────────────────────────────────────
--  Visual mode
-- ──────────────────────────────────────────────────────────────

vim.keymap.set("v", "<", "<gv",  { desc = "indent left (keep selection)" })
vim.keymap.set("v", ">", ">gv",  { desc = "indent right (keep selection)" })
vim.keymap.set("v", "K", "JVgq", { desc = "join and reflow" })
vim.keymap.set("v", "j", "gj", { desc = "visual-line down" })
vim.keymap.set("v", "k", "gk", { desc = "visual-line up" })
vim.keymap.set("v", ";", ":",    { desc = "command-line" })

-- Paste over selection without polluting unnamed register
vim.keymap.set("v", "p", '"_dP', { desc = "paste over (keep register)" })

-- Inner-line text object: il = between first non-blank and last non-blank char
vim.keymap.set("x", "il", "g_o^",          { desc = "inner line" })
vim.keymap.set("o", "il", ":normal vil<CR>", { desc = "inner line" })

-- Move block of text (respects indentation)
vim.keymap.set("v", "<down>", ":m '>+1<CR>gv=gv", { desc = "move block down" })
vim.keymap.set("v", "<up>",   ":m '<-2<CR>gv=gv", { desc = "move block up" })

-- ──────────────────────────────────────────────────────────────
--  Clipboard bridges  (unnamed register != system clipboard)
-- ──────────────────────────────────────────────────────────────
-- NoetherVim leaves the unnamed register alone so transient edits
-- (ddp, xp, ciwp, ...) don't pollute the OS clipboard.  Reach for
-- these explicit bridges when you want the system clipboard:
--
--   <leader>y / <leader>Y       yank (motion / line) to clipboard
--   <leader>p / <leader>P       paste (after / before) from clipboard
--   visual Y / P                shorthand yank / paste to clipboard
--   insert <C-v>                paste clipboard (see caveat below)
--   cmdline <C-y>               yank cmdline text to clipboard
--   cmdline <C-r>*              insert clipboard (Vim built-in)
--
-- Insert <C-v> shadows Vim's "insert next char literally" default.
-- Substitutes: <C-q> (literal-insert in most terminals), <C-r>+, or
-- the cmdline where <C-v>{char} is unshadowed (useful with :verbose).

-- Composable operators (operator-pending in normal, acts on selection in visual)
vim.keymap.set({ "n", "v" }, "<leader>y", '"*y', { desc = "yank to clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>p", '"*p', { desc = "paste from clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>P", '"*P', { desc = "paste before from clipboard" })
vim.keymap.set("n", "<leader>Y", '"*yy', { desc = "yank line to clipboard" })

-- Visual paste variants: keep BOTH the unnamed register and clipboard pristine
vim.keymap.set("v", "<leader>p", '"_d"*P', { desc = "paste clipboard (keep registers)" })
vim.keymap.set("v", "<leader>P", '"_d"*P', { desc = "paste clipboard (keep registers)" })

-- Visual quick shortcuts (post-selection)
vim.keymap.set("v", "Y", '"*y',    { desc = "yank to clipboard" })
vim.keymap.set("v", "P", '"_d"*P', { desc = "paste clipboard (keep registers)" })

-- ──────────────────────────────────────────────────────────────
--  Select mode
-- ──────────────────────────────────────────────────────────────

-- Alphanumeric keys in select mode replace the selection (natural text editing)
for _, key in ipairs({ "c", "g", "j", "k", "T" }) do
  vim.keymap.set("s", key, key)
end
-- Escape once → visual; twice → normal
vim.keymap.set("s", "<esc>", "<esc><esc>",  { desc = "escape to normal" })
-- Jump to end of previous selection
vim.keymap.set("s", "<c-a>", "<esc>`>a",  { desc = "jump past selection" })

-- ──────────────────────────────────────────────────────────────
--  Command-line mode
-- ──────────────────────────────────────────────────────────────

vim.keymap.set("c", "<C-l>",   '<C-r>=expand("%:p:h")<CR>', { desc = "insert cwd" })
vim.keymap.set("c", "<c-y>", function()
  local text = vim.fn.getcmdline()
  vim.fn.setreg("*", text)
  local preview = #text > 60 and (text:sub(1, 57) .. "...") or text
  vim.notify(preview, vim.log.levels.INFO, { title = "yanked to clipboard" })
end, { desc = "yank cmdline to clipboard" })
vim.keymap.set("c", "<m-bs>",  "<c-w>",                    { desc = "delete word" })
-- Redirect command output to a scratch buffer
vim.keymap.set("c", "<c-o>",   "<c-b>Redir <c-e>",         { desc = "redirect output to buffer" })

-- ──────────────────────────────────────────────────────────────
--  All modes -- <Esc> cleanup
-- ──────────────────────────────────────────────────────────────

vim.keymap.set({ "n", "v" }, "<Esc>", function()  -- clear highlights, dismiss notifications
  vim.cmd.stopinsert()
  if vim.fn.mode():match("^[vV\22]") then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  vim.cmd.noh()
  if package.loaded["notify"]  then require("notify").dismiss() end
  if package.loaded["snacks"]  then require("snacks").notifier.hide() end
  if package.loaded["nvim-dap-virtual-text"] then
    require("nvim-dap-virtual-text").refresh()
  end
  vim.cmd("echo ''")
end, { silent = true })

-- ──────────────────────────────────────────────────────────────
--  Mouse
-- ──────────────────────────────────────────────────────────────

vim.keymap.set({ "n", "v" }, "<RightMouse>", function()
  vim.cmd.exec('"normal! \\<RightMouse>"')
  local ok, menu = pcall(require, "menu")
  if ok then
    local options = vim.bo.ft == "snacks_layout_box" and "nvimtree" or "default"
    menu.open(options, { mouse = true })
  end
end, { desc = "context menu" })
