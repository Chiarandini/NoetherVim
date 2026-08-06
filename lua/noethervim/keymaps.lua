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
-- Undo tree: mbbill/undotree.  Selecting a node shows the diff in a
-- side pane WITHOUT applying it; press <CR> to actually move the
-- buffer to that state.  This is the non-destructive counterpart to
-- Neovim's builtin nvim.undotree, which applies state on every
-- CursorMoved.
vim.keymap.set("n", "<c-w><c-u>", "<cmd>UndotreeToggle<cr>", { desc = "toggle undo tree" })

-- Toggle a 12-line terminal along the bottom, reusing the same terminal
-- buffer every time rather than stacking a new one per press.  This
-- shadows Vim's builtin <C-w>t (go to the top window); `1<C-w>w` does
-- that instead.
local term_buf
vim.keymap.set("n", "<c-w>t", function()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_get_buf(win) == term_buf then
      if #wins > 1 then vim.api.nvim_win_close(win, false) end
      return
    end
  end
  vim.cmd("botright split")
  vim.api.nvim_win_set_height(0, 12)
  vim.wo.winfixheight = true
  if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
    vim.api.nvim_win_set_buf(0, term_buf)
  else
    vim.cmd.term()
    term_buf = vim.api.nvim_get_current_buf()
  end
end, { desc = "toggle terminal" })

-- <Esc><Esc> leaves terminal mode.  A single <Esc> still reaches the
-- program, and autocmds.lua shortens 'timeoutlen' while terminal mode is
-- active so it is not held back for the full default second.
vim.keymap.set("t", "<esc><esc>", "<c-\\><c-n>", { desc = "exit terminal mode" })

-- Toggle the quickfix window.  A one-shot action rather than a search, so it
-- lives under <Leader> and not in the SearchLeader namespace.
vim.keymap.set("n", "<leader>q", function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.fn.getwinvar(win, "&buftype") == "quickfix" then
      vim.cmd("cclose")
      return
    end
  end
  vim.cmd("copen")
end, { desc = "[q]uickfix toggle" })
-- <c-w>u: set in commands.lua (show unsaved buffers)

-- Resize splits with arrow keys. Arrow direction is always direction of
-- motion: plain <Arrow> pushes the near edge outward (grow); <S-Arrow>
-- pulls the far edge inward (shrink). All eight are silent no-ops when
-- there is no neighbor on the moving edge. See util/smart_resize.lua.
--
-- Plain arrows also fall back to hjkl cursor motion when the current
-- window has nothing to resize against (single non-floating window in
-- the tab, or we're inside a floating window). Counts pass through, so
-- e.g. `5<Down>` still jumps 5 lines via the j remap.
local sr = require("noethervim.util.smart_resize")
-- nvim_feedkeys (not :normal) — :normal leaves the count pending, which
-- then collides with the count baked into vline_move's expr return
-- ("5gj"), making the j/k remap fire with a doubled count (1<Down> → 11
-- lines, 2<Down> → 21 lines). Feedkeys queues the keys after our
-- callback returns, with no pending count from our side.
local function arrow_or_motion(motion, resize_fn)
  return function()
    if sr.is_solo() then
      local count = vim.v.count
      local keys = (count > 0 and tostring(count) or "") .. motion
      vim.api.nvim_feedkeys(keys, "m", false)
    else
      resize_fn()
    end
  end
end
vim.keymap.set("n", "<up>",      arrow_or_motion("k", sr.grow_up),    { desc = "grow up / move up (solo)" })
vim.keymap.set("n", "<down>",    arrow_or_motion("j", sr.grow_down),  { desc = "grow down / move down (solo)" })
vim.keymap.set("n", "<left>",    arrow_or_motion("h", sr.grow_left),  { desc = "grow left / move left (solo)" })
vim.keymap.set("n", "<right>",   arrow_or_motion("l", sr.grow_right), { desc = "grow right / move right (solo)" })
vim.keymap.set("n", "<S-up>",    function() sr.shrink_down()  end, { desc = "pull bottom edge up" })
vim.keymap.set("n", "<S-down>",  function() sr.shrink_up()    end, { desc = "pull top edge down" })
vim.keymap.set("n", "<S-left>",  function() sr.shrink_right() end, { desc = "pull right edge left" })
vim.keymap.set("n", "<S-right>", function() sr.shrink_left()  end, { desc = "pull left edge right" })

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
--  Normal mode -- closing things  (Z prefix)
-- ──────────────────────────────────────────────────────────────

-- A grid, not a list of initials.  Vim's own ZZ (write and leave) and ZQ
-- (force out) are the bottom and top of the first column; the rest of the
-- table extends that ladder.
--
--                 Z A Q         X S W          C D E
--               this window   everything    this buffer
--   top     force, discard    ZQ  :q!       ZW  :qa!        ZE  :bd!
--   home    refuse if dirty   ZA  :q        ZS  :qa         ZD  :bd
--   bottom  save first        ZZ  :x        ZX  :wa|qa!     ZC  :w|bd

vim.keymap.set("n", "ZA", "<cmd>q<cr>",            { desc = "close window" })
vim.keymap.set("n", "ZS", "<cmd>qa<cr>",           { desc = "quit all" })
vim.keymap.set("n", "ZW", "<cmd>qa!<cr>",          { desc = "quit all! (kill nvim)" })
vim.keymap.set("n", "ZX", "<cmd>wa<bar>qa!<cr>",   { desc = "save what you can, then force-quit" })
vim.keymap.set("n", "ZD", "<cmd>bdelete<cr>",      { desc = "delete buffer" })
vim.keymap.set("n", "ZE", "<cmd>bdelete!<cr>",     { desc = "delete buffer force" })
vim.keymap.set("n", "ZC", "<cmd>write<bar>bdelete<cr>", { desc = "save and delete buffer" })
vim.keymap.set("n", "ZR", function()
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

-- gC (visual): per-line comment toggle.
-- Vim's builtin `gc` operator picks one direction for the whole range
-- (comment-everything-or-uncomment-everything based on the majority
-- state).  `gC` runs the toggle line-by-line so a mixed selection ends
-- up with each line in the *opposite* state -- handy when you want to
-- swap which lines in a block are active vs. commented.
--
-- Implementation notes:
--   * Visual-mode mappings exit visual mode before the RHS runs, so we
--     read the range from the `'<` / `'>` marks (which Vim sets on the
--     way out), not from `v` / `.`.
--   * `<cmd>` keymap form prevents the leading `:` from leaving artifacts
--     in the cmdline, and because it doesn't exit visual we capture the
--     range cleanly.
--   * The toggle uses Neovim's built-in `gcc` operator (Nvim 0.10+).
local function invert_comment_visual()
  local start_line = vim.fn.line("'<")
  local end_line   = vim.fn.line("'>")
  if start_line == 0 or end_line == 0 or start_line > end_line then
    vim.notify("no visual range for gC", vim.log.levels.WARN)
    return
  end
  local commentstring = vim.bo.commentstring or ""
  local prefix = commentstring:gsub("%%s.*", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if prefix == "" then
    vim.notify("no commentstring for filetype " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end
  -- Save and restore the cursor so the user lands where they started.
  local saved_pos = vim.api.nvim_win_get_cursor(0)
  for lnum = start_line, end_line do
    local line = vim.fn.getline(lnum)
    if line:match("%S") then
      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
      -- gcc is the line-comment operator; without `!` it follows the
      -- builtin comment plugin if present.
      vim.cmd("normal gcc")
    end
  end
  pcall(vim.api.nvim_win_set_cursor, 0, saved_pos)
end
vim.keymap.set({ "v", "x" }, "gC", function()
  -- Exit visual first so '< / '> are populated, then run.
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  invert_comment_visual()
end, { silent = true, desc = "invert comment per-line" })

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

-- Composable operators (operator-pending in normal, acts on selection in visual).
-- Normal-mode p/P get the plain `"*p`/`"*P`; visual-mode p/P use a different
-- sequence (immediately below) that preserves both registers, so the
-- {n,v} table on those lines would otherwise be a write that we then
-- immediately overwrite.
vim.keymap.set({ "n", "v" }, "<leader>y", '"*y', { desc = "yank to clipboard" })
vim.keymap.set("n",          "<leader>p", '"*p', { desc = "paste from clipboard" })
vim.keymap.set("n",          "<leader>P", '"*P', { desc = "paste before from clipboard" })
vim.keymap.set("n",          "<leader>Y", '"*yy', { desc = "yank line to clipboard" })

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
  -- Dismiss LSP hover/diagnostic floats spawned via util.open_floating_preview
  -- (K, gl, vim.lsp.buf.hover, etc.).  vim.lsp.util sets b:lsp_floating_preview
  -- on the source buffer to the float's winid.
  local lsp_float = vim.b.lsp_floating_preview
  if lsp_float and vim.api.nvim_win_is_valid(lsp_float) then
    pcall(vim.api.nvim_win_close, lsp_float, true)
  end
  -- Dismiss DAP inspection floats (dapui.eval = `dapui_hover`,
  -- dap.ui.widgets.hover/preview = `dap-float`) when the cursor isn't inside
  -- one, so focusing into the float to scroll/expand keeps it open.
  local cur_win = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= cur_win and vim.api.nvim_win_get_config(win).relative ~= "" then
      local ok, ft = pcall(vim.api.nvim_get_option_value, "filetype",
        { buf = vim.api.nvim_win_get_buf(win) })
      if ok and (ft == "dapui_hover" or ft == "dap-float") then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end
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

-- ──────────────────────────────────────────────────────────────
--  Inspection (SearchLeader+c prefix)
-- ──────────────────────────────────────────────────────────────
-- Registered here rather than alongside the pickers in inspect.lua, which
-- only runs at VeryLazy.  That is too late on both counts: it would land
-- after lua/user/overrides/*.lua and so beat a user override, and it is
-- past the point where the keymap-source registry is still recording, so
-- the diff picker and guide would have no file+line to jump to.
--
-- The bodies require noethervim.inspect on first press, not at load time,
-- so registering early costs nothing at startup.
--
-- SearchLeader+cu (user settings), +cc (config lua), +cf (ftplugins) and
-- +cs (snippets) are defined in snacks.lua, in the same namespace.

local SearchLeader = require("noethervim.util").search_leader

--- Call `name` on noethervim.inspect, loading the module on first use.
local function inspect(name)
  return function() require("noethervim.inspect")[name]() end
end

vim.keymap.set("n", SearchLeader .. "cf", inspect("files"),         { desc = "NoetherVim [f]iles" })
vim.keymap.set("n", SearchLeader .. "cg", inspect("grep"),          { desc = "NoetherVim [g]rep" })
vim.keymap.set("n", SearchLeader .. "cb", inspect("bundles"),       { desc = "NoetherVim [b]undles" })
vim.keymap.set("n", SearchLeader .. "ct", inspect("templates"),     { desc = "NoetherVim [t]emplates" })
vim.keymap.set("n", SearchLeader .. "ck", inspect("diff_keymaps"),  { desc = "diff [k]eymaps" })
vim.keymap.set("n", SearchLeader .. "co", inspect("diff_options"),  { desc = "diff [o]ptions" })
vim.keymap.set("n", SearchLeader .. "ca", inspect("diff_autocmds"), { desc = "diff [a]utocmds" })
vim.keymap.set("n", SearchLeader .. "cd", inspect("diff_file"),     { desc = "[d]iff file" })

vim.keymap.set("n", SearchLeader .. "?", function()
  require("noethervim.guide").open()
end, { desc = "keymap guide" })

vim.keymap.set("n", "<leader>i", "<cmd>edit $MYVIMRC<cr>", { desc = "open [i]nit.lua" })

-- Creating and opening an override file is an action on the current buffer,
-- not a search, so it sits under <Leader> rather than SearchLeader+c.
vim.keymap.set("n", "<leader>e", inspect("override"), { desc = "[e]dit override" })
