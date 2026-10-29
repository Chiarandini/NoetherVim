-- NOETHERVIM OPTIONS
-- see :help Noethervim -> Options for explanations of the more contentious choices (ex. autowrite
-- and autowriteall)
--
-- Sourced by setup(), never required, so `:verbose set` names this file.

-- Enable the Lua bytecode cache (must be first for maximum benefit)
vim.loader.enable()

-- On macOS, Neovim launched outside a login shell may miss Homebrew's bin dirs.
-- Add them early so tools like tree-sitter, node, rg, etc. are always findable.
if vim.fn.has("mac") == 1 then
  for _, p in ipairs({ "/opt/homebrew/bin", "/usr/local/bin" }) do
    if vim.fn.isdirectory(p) == 1 and not vim.env.PATH:find(p, 1, true) then
      vim.env.PATH = p .. ":" .. vim.env.PATH
    end
  end
end

-- Every default yields to a value you set before NoetherVim loaded (at the
-- top of init.lua, or in a plugin's init): Neovim records who set each
-- option, and an option that is yours is left as it is.
local claimed = require("noethervim.default").claimed
local opt = setmetatable({}, {
  __newindex = function(_, name, value)
    if not claimed(name) then vim.o[name] = value end
  end,
})
local function append(name, value)
  if not claimed(name) then vim.opt[name]:append(value) end
end

-- Line numbers
opt.number         = true
opt.relativenumber = true

-- Mouse
opt.mouse          = "a"
opt.mousemoveevent = true

-- File handling
opt.autowrite    = true
opt.autowriteall = false
opt.autoread     = true
opt.swapfile     = false

-- Text layout
-- wrap is OFF globally; the writing profile (autocmds.lua) re-enables it
-- for writing filetypes. The breakindent / linebreak / showbreak settings
-- only take effect when wrap is on, so they're harmless here and active
-- in writing buffers.
opt.wrap          = false
opt.breakindent   = true
opt.linebreak     = true
opt.breakindentopt = "sbr,min:0,shift:0"
-- Empty: the wrapped-line marker is drawn in the number column by the
-- writing profile (autocmds.lua) instead, so it costs no text column and
-- continuation lines align with the text they continue.
opt.showbreak     = ""

-- listchars: makes `list = true` (set by the code profile in autocmds.lua)
-- readable. tab shows as arrow, trailing whitespace as middle dot.
opt.listchars = "tab:→ ,trail:·,nbsp:␣,extends:›,precedes:‹"
-- ── Filetype-scoped defaults (seeds) ──────────────────────────────────────
-- These buffer-local options are set per filetype by the ftplugin layer
-- (Neovim's bundled ftplugins, the language bundles, an after/ftplugin), which
-- runs after this file and takes precedence. The values here are the fallback
-- for buffers whose ftplugin sets nothing, not a global policy; to change the
-- effective value, set it in the filetype layer (a FileType autocmd or
-- after/ftplugin/<ft>.lua), not here or in user/options.lua.
-- See :help noethervim-option-layers.
opt.textwidth  = 100
opt.tabstop    = 4
opt.shiftwidth = 4

-- formatoptions (seed; the writing profile re-adds `t` for writing):
--   c  auto-wrap comments using textwidth
--   r  continue comment leader after <Enter>
--   o  continue comment leader after o/O
--   q  allow formatting comments with gq
--   1  don't break line after a one-letter word
--   j  remove comment leader when joining lines
--   n  recognize numbered lists (uses formatlistpat)
-- `t` (auto-wrap text) is omitted so code files don't break mid-line while
-- typing (delegated to formatters).
opt.formatoptions = "croq1jn"

-- Diff
append("diffopt", "vertical")

-- Search
opt.ignorecase = true
opt.infercase  = true
opt.incsearch  = true
opt.smartcase  = true
opt.hlsearch   = true    -- <Esc> clears; [oh/]oh toggles persistently

-- Indentation behaviour (tabstop / shiftwidth are seeded above; ftplugins,
-- editorconfig, and guess-indent.nvim refine them per buffer).
-- autoindent: copy indent from the line above when starting a new line
-- (this is how `O` and `o` keep your code aligned). The Neovim default
-- is already `true`, but set it explicitly so a stray ftplugin / runtime
-- file flipping it off can be more easily debugged.
-- copyindent + preserveindent: when re-indenting, reuse the existing
-- whitespace structure (tabs vs spaces, mixed leading runs) instead of
-- normalising to shiftwidth. This is what makes `O` on a deeply-indented
-- line keep its full indent run instead of snapping back to column 0.
opt.autoindent     = true
opt.copyindent     = true
opt.preserveindent = true

-- Splits prefer bottom-right
opt.splitbelow = true
opt.splitright = true

-- Scrolling
opt.scrolloff     = 4
opt.sidescrolloff = 8
opt.smoothscroll  = true

-- UI
append("shortmess", "T")
opt.visualbell    = true
opt.termguicolors = true
opt.foldcolumn    = "0"
opt.foldlevel     = 99
opt.foldlevelstart = 99
opt.foldenable    = true
opt.fillchars     = "fold: "

-- Autochdir
opt.autochdir = false

-- Session restoration
-- `localoptions` is intentionally omitted: it captures every buffer-local
-- option at save time, which then overrides updated globals when the
-- session reloads (e.g. spelllang stays "en_us" long after the distro
-- default moved to "en"). NoetherVim's FileType-driven writing/code
-- profiles re-establish the per-buffer values that matter (wrap, spell,
-- list, conceallevel, ...) on every buffer load, so capturing them in
-- sessions is mostly redundant. Add `localoptions` back in your personal
-- options.lua if you depend on session-restoring buffer-local state.
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal"

-- Undo
opt.undofile   = true
opt.undolevels = 1000
opt.undoreload = 10000

local undodir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undodir, "p")
opt.undodir = undodir

-- Cache/swap dirs (use stdpath so they work regardless of appname)
-- NOTE: swap file are off  by default (see Noethervim doc for the explanation)
opt.dir = vim.fn.stdpath("state") .. "/swap"
vim.fn.mkdir(vim.o.dir, "p")

-- Spell
-- "en" accepts all English regional dialects (US, UK, CA, AU, NZ) so the
-- default doesn't flag "colour"/"color" as wrong for either camp. Narrow
-- in your personal config if you want strict regional checking, e.g.
-- vim.opt.spelllang = { "en_us" } or { "en_gb" } or { "en_us", "de_de" }.
opt.spelllang = "en"
-- Spellfile lives in the user's config dir; with the user layer off,
-- words added go to a scratch file instead.
local user_dir = require("noethervim.config").user_dir()
if user_dir then
  opt.spellfile = user_dir .. "/spell/en.utf-8.add"
else
  vim.fn.mkdir(vim.fn.stdpath("state") .. "/noethervim/spell", "p")
  opt.spellfile = vim.fn.stdpath("state") .. "/noethervim/spell/en.utf-8.add"
end

-- History
opt.shada = "'1000,<50,s10,h"

-- Wildignore
append("wildignore", { "*/.git/*", "*.swp" })
