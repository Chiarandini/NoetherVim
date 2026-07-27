# Your first session

You have installed NoetherVim and opened Neovim. This is the half hour that
gets you from "it starts" to "I know where things are".

Nothing here is required reading. If you would rather explore, the two
commands worth knowing before you close this page are `<Space>?` (the keymap
guide) and `:checkhealth noethervim`.

If you are here primarily for LaTeX or Typst, read this page first for the
general layout, then continue with
[onboarding for mathematicians](mathematicians.md).

---

## 1. What you are looking at

On a fresh install, `nvim` with no arguments opens a dashboard. Everything
below assumes you are in a normal buffer, so press `f` to find a file, or
just `:e some-file`.

Three things are already true without any configuration:

- The colorscheme is gruvbox. Change it with `colorscheme` in
  `lua/user/config.lua`, or enable the `colorscheme` bundle for a picker.
- LSP, completion, treesitter, formatting, and diagnostics are configured.
  Open a `.lua` or `.py` file and they attach on their own.
- No bundles are enabled. The core is fully functional without them; bundles
  are for workflows you opt into (LaTeX, debugging, Obsidian, git UIs).

## 2. The prefixes

This is the highest-value thing on the page. NoetherVim's keymaps are sorted
into five namespaces, and knowing which prefix owns what removes most of the
guessing:

- `<Space>` (SearchLeader): opens a picker. Find files, grep, LSP symbols,
  diagnostics, git, config. If a key is under `<Space>`, it fuzzy-searches
  something. Change the prefix with `vim.g.mapsearchleader` in `init.lua`.
- `<Leader>` (`\` by default): global actions. Toggle the quickfix window,
  format, run, open your override file.
- `<LocalLeader>` (`,` by default): filetype actions. Compile a LaTeX
  document, run a test, send to a REPL.
- `<C-w>`: windows and panels, as in stock Vim, plus a few additions
  (`<C-w><C-u>` undo tree, `<C-w>t` terminal).
- `[` and `]`: paired navigation and toggles, following vim-unimpaired.
  `[q` / `]q` move through the quickfix list; `[o` enables an option and
  `]o` disables it, so `[ow` turns wrap on and `]ow` turns it off.

Press `<Space>` and wait: which-key shows what is available under it. The
same works for `<Leader>`, `[`, and `<C-w>`.

## 3. Take the tour

Four commands, in the order worth running them:

- `<Space>?` (`:NoetherVim keymap-guide`): every active keymap, grouped by
  namespace. It reads live state, so it reflects the bundles you enabled and
  your own additions. `<CR>` on a line jumps to where that keymap was
  defined.
- `:checkhealth noethervim`: confirms your terminal, tools, and config are
  in order. Worth running once now, and again whenever something misbehaves.
- `<Space>cb` (`:NoetherVim bundles`): the bundle catalogue, with
  descriptions and which are active.
- `:NoetherVim conventions`: a one-screen summary of load order and where
  overrides go.

## 4. Read the defaults

NoetherVim is opinionated, and the opinions are collected in one place. It is
worth ten minutes to skim them now rather than discovering them by surprise
later.

Press `<Space>ct`, pick `user/config.example.lua`, and press `<C-y>`. That
stamps an annotated copy into `lua/user/config.lua` (a diff prompt shows you
the change first). Every key is commented out, so the file changes nothing
until you uncomment something.

Read it top to bottom once. It is the full list of what NoetherVim lets you
change about its own behaviour: colorscheme, statusline shape, the Tab-key
philosophy for completion, which filetypes count as "writing", what a bare
`q` closes. Uncomment what you disagree with.

The file is also typed. With the `---@type noethervim.UserConfig` line at the
top, `<C-Space>` inside the table completes key names and shows the
documentation for each one, and typos get flagged.

## 5. Enable what you need

Bundles are opt-in plugin groups. Open `<Space>cb`, highlight one, and press
`<C-y>` to enable it (`<C-x>` to disable). A diff prompt shows the exact edit
to your `init.lua` before anything is written, then restart Neovim.

Reasonable starting points: `tools.git` if you want a git UI,
`languages.<your language>`, `navigation.harpoon` for fast file switching,
`ui.colorscheme` if gruvbox is not for you.

The [bundle catalogue](../bundles.md) lists all of them.

## 6. Where the rest lives

- `:help noethervim` is the reference manual. It is not long, and it is the
  authoritative source for everything summarised here.
- Your configuration goes in `~/.config/nvim/lua/user/`. `<Space>ct` stamps
  a starting template for each file; `:help noethervim-user-config` explains
  the layering.
- `:NoetherVim diff keymaps`, `diff options`, and `diff autocmds` show what
  you have changed relative to the distro defaults, which is the fastest way
  to answer "did my override take effect".

## 7. If something looks wrong

- Run `:checkhealth noethervim` first.
- To confirm a problem is yours rather than the distro's, start with
  `NOETHERVIM_NO_USER=1 nvim`, which skips every file in `lua/user/`.
- `:Lazy` shows plugin status and load times; `:Lazy update` updates
  everything including the distro.
