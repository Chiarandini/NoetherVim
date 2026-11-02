# News

Breaking and behavior changes, newest first, each with what to do about it.
During the alpha, changes land without deprecation periods; this file is
where they are listed.

## 2026-11-02

- **`vim.g.noethervim_auto_install = false` also stops treesitter parser
  installs,** both the parsers core and your bundles list and the one for
  each filetype you open. Install them with `:TSInstall`;
  `:checkhealth noethervim` lists the ones missing.
- **The java bundle needs a JDK 25:** jdtls 1.63 and later bundle an Eclipse
  compiler built for Java 25, and on an older JDK the language server starts
  and never comes up. The first Java buffer says so when the JDK is older,
  and `:checkhealth noethervim` names the one it found.
- **NoetherVim's own files open read-only,** however they are opened, unless
  you load a checkout with `vim.g.noethervim_dev`: lazy.nvim manages the
  installed copy, and an edit there is lost on the next `:Lazy update` or
  stops it. `gf` or `<C-]>` on an `import` string in `init.lua` opens that
  bundle's file.

## 2026-11-01

- **`init.lua` imports `noethervim.core`:** in the NoetherVim spec, change
  `import = "noethervim.plugins"` to `import = "noethervim.core"`. Until
  then lazy.nvim reports `No specs found for module "noethervim.plugins"`
  and none of NoetherVim's plugins load. The
  `config = function() require("noethervim").setup() end` line can go too,
  and so can `matchit`, `matchparen` and `netrwPlugin` in
  `disabled_plugins`: vim-matchup and oil switch those off, and back on
  when you disable them. `init.lua.example` (template v4) has the new
  shape; `:checkhealth noethervim` names whatever is left.
- **NoetherVim's spec files moved to `lua/noethervim/core/<category>/`.**
  An override created with `:NoetherVim override` before the move is
  reported by `:checkhealth noethervim` as overriding a file that no
  longer exists; run `:NoetherVim override` from the file's new place to
  clear it. `require("noethervim.plugins.statusline.context")` is now
  `require("noethervim.lib.statusline.context")`.
- **argmark and mini.sessions are bundles:** the arglist keys
  (SearchLeader ae, `<Leader>aa`, `ax`, `a<Leader>`, `ac`, `aX`, `aA`) come
  with `navigation.argmark`; `:SaveSession` and the dashboard's Sessions key
  with `tools.named-sessions`. Import either to keep it. Restoring the last
  session of a directory (the dashboard's Restore Session) stays in core.
- **`navigation.editing-extras` is `editing.comment-box`:** change the
  import in `init.lua`.
- **trouble.nvim is the `tools.trouble` bundle:** core's `<C-w>Q` lists
  every diagnostic in the quickfix list, where `]q`, `[q`, `]Q` and `[Q`
  are Neovim's own and walk it. Import the bundle for Trouble's panel on
  `<C-w>Q` and for `]q` following it while it is open.
- **`<RightMouse>` comes with nvzone/menu:** disabling it gives the key back
  to Neovim's own popup menu; a second right-click no longer stacks a second
  menu. `<Esc>` no longer dismisses nvim-notify toasts or refreshes DAP
  virtual text; `:DapVirtualTextForceRefresh` does the latter.
- **A Neovim older than 0.12 is named at startup:** NoetherVim needs 0.12,
  and on an older one parts of it fail one by one with no common cause in
  sight. The README's Requirements section lists ways to install a current
  Neovim.

## 2026-10-30

- **`opts` on rustaceanvim, neominimap and fff merge with NoetherVim's,**
  as on any plugin; they used to raise an error (rustaceanvim, neominimap)
  or replace the bundle's settings (fff). A `vim.g.rustaceanvim` or
  `vim.g.neominimap` of yours, set above `lazy.setup()`, still replaces
  NoetherVim's (`:help noethervim-user-plugins-globals`).
- **Picker keys open a verb, which any engine can serve:** SearchLeader
  ff, fp, fo, fb, gg, gp, r, t and w, the dashboard's `f` and `o`, Oil's
  `gf`/`gG` and insert `<C-S-c>` open `files`, `grep`, `recent`,
  `buffers`, `resume`, `headings`, `labels` or `citations`. snacks serves
  them as before; `pick.route` in `lua/user/config.lua` hands one to
  another engine, `pick.engines` adds your own (`:help noethervim-pick`).
- **SearchLeader+gw greps the word under the cursor**, or the selection.
- **The navigation/fff bundle** opens fff for a project's files and grep,
  with `[oF`/`]oF` to switch back to snacks. If you route fff over
  NoetherVim's keys yourself, import the bundle instead.
- **block.nvim left the eye-candy bundle, and `[oB`/`]oB` with it:** on
  Neovim 0.12 it fails in any buffer without a tree-sitter parser, and it
  is no longer maintained. Nothing replaces it.
- **`profiles.conservative` is a filetype map, like `q_close`:** write
  `conservative = { tex = false, markdown = true, size_kb = 500 }`; `true`
  adds a filetype and `false` removes one; tex is the default.
- **A `lua/user/config.lua` key nothing reads warns at startup:** a typo or
  a renamed key is named when Neovim starts, not only by
  `:checkhealth noethervim`.
- **A TeX file offers the latex bundle once:** in an install without it, the
  first TeX buffer opens a window saying what the bundle adds; `<CR>` shows
  the `init.lua` change that enables it, `<Esc>` closes it for good.
- **The statusline is built from segments, by id:** rename these keys in
  `statusline` in `lua/user/config.lua`.
  - `edge_style`, `colors`, `mode_background`, `tab_modified_indicator` and
    `git_click` move under `style`.
  - `filetype_profile = true` is now `layout = { profile = true }`; `layout`
    also hides or moves any block or segment by id.
  - `extra_right` is gone: declare a segment in `segments` instead
    (`:help noethervim-statusline-segments`).
  - `statusline_enabled = false` is gone: put
    `{ "rebelot/heirline.nvim", enabled = false }` in `lua/user/plugins/`;
    `bars = { tabline = false }` drops a single bar.
  - `require("noethervim.statusline").register_busy_override(fn)` is gone: a
    `busy` entry on NoetherVim's spec claims the slot
    (`:help noethervim-statusline-busy`).

  The VimTeX, PDF size and DAP readouts come with their bundles, and any
  statusline shows them with `require("noethervim.statusline").text(id)`.
- **A plugin's toggles and labels go with it:** `[oC`, `[oA`, `[oL`, `[oV`,
  `[oW`, `[oG`, `[oD` and `[o<C-t>` are declared in their plugin's spec, as
  are the which-key labels for `<leader>d`, `<leader>t`, `<leader>o` and the
  rest, so `{ "<plugin>", enabled = false }` removes them too. `[om` comes
  with the markdown bundle, `<leader>rT` with better-term. Without the latex
  bundle, tex buffers no longer complete image file names.

## 2026-10-29

- **`:help noethervim-api` lists the names a config may call:** public,
  provisional and contributor. Anything else under `lua/noethervim/` can
  change without a line here; in a checkout,
  `nvim -l tools/check-surface.lua` lists your config's uses outside it.
- **`:checkhealth neothervim` is gone:** a bare `:checkhealth` ran
  NoetherVim's checks twice through it. Use `:checkhealth noethervim`;
  `:NeotherVim` and `:help neothervim` stay.
- **Public names for the modules configs reach into:** rename these
  requires.
  - `noethervim.util.colorscheme` is `noethervim.theme`: `tweak()` and
    `apply()` as before, and `palette()` in place of
    `require("noethervim.util.palette").resolve()`.
  - `noethervim.util.run` is `noethervim.run`, and `noethervim.util.spell`
    is `noethervim.profiles.spell`.
  - `require("noethervim.toggles")._notify` is `.notify`.
  - `noethervim.util.filetypes` is private: `require("noethervim.profiles").classes()`
    maps each filetype with a class of its own to `"writing"`, `"code"` or
    `false`.
- **`lua/user/config.lua` groups its settings by concept:** rename these
  keys; `:checkhealth noethervim` names any key it no longer knows.
  - `completion_style = "x"` is now `completion = { style = "x" }`.
  - `spell_in_code`, `blink_conservative_filetypes` and
    `blink_conservative_size_kb` move under `profiles`:
    `profiles = { spell_in_code = true, conservative = { filetypes = ..., size_kb = ... } }`.
  - `writing_filetypes = { "x" }` is now `profiles = { classes = { x = "writing" } }`,
    and `non_code_filetypes = { "x" }` is `classes = { x = false }`.
  - `q_close_filetypes = { "x" }` is now `q_close = { x = true }`; `false`
    removes one of the defaults.
  - `obsidian_vault` is gone: name the vault in obsidian.nvim's `opts`,
    `workspaces = { { name = "vault", path = "..." } }`.
  - `drop = false` is gone: `{ "folke/drop.nvim", enabled = false }` in
    `lua/user/plugins/`.
  - `vim.g.noethervim_dashboard = false` is gone:
    `{ "folke/snacks.nvim", opts = { dashboard = { enabled = false } } }`.
- **`:NoetherVim files` names your counterpart:** a source file that a file
  of yours can change is followed by it (`→ lua/user/plugins/oil.lua`).
  `:NoetherVim diff` lists only those files.
- **The arglist keys say what they did:** `<Leader>aa`, `ax`, `aX`, `aA` and
  `ac` report the change and the arglist size, through `toggle_feedback`.
- **Your hook files run last:** `lua/user/{options,keymaps,autocmds,highlights}.lua`
  now run once every plugin NoetherVim starts is set up, so a value in them
  wins over those plugins too. A `vim.g` value a plugin reads the moment it
  loads at startup belongs at the top of `init.lua` instead.
- **`lua/user/lsp/` and `lua/user/overrides/` are no longer read:** move a
  server's settings to `after/lsp/<server>.lua` returning the settings
  table (it merges over NoetherVim's), and other code to `after/plugin/`.
  `:checkhealth noethervim` names the files still there.
- **Language servers are enabled at startup:** `vim.lsp.enable(name, false)`
  in `lua/user/options.lua` now sticks, and `lsp = { [name] = false }` in
  `lua/user/config.lua` drops NoetherVim's settings for a server.
- **`vim.g.noethervim_auto_install = false` also covers language servers:**
  the servers in lspconfig's `ensure_installed` are no longer fetched with it
  set; install them with `:Mason`.
- **`:NoetherVim override!` is gone:** `:NoetherVim override` opens the file
  of yours that changes the current one, adding a commented starting point
  once you accept it as a diff.
  `:NoetherVim diff` lists only what your own files changed.
- **Your buffer settings beat the filetype profiles:** a `spell`,
  `conceallevel`, `list`, `wrap` or `linebreak` you set for a buffer
  (`after/ftplugin/`, a `FileType` autocmd, a modeline, `:setlocal`, `]os`)
  is kept in every window showing it, across window switches. A global
  `spell`, `conceallevel` or `list` in `lua/user/options.lua` now holds in
  prose and code buffers too; prose still wraps whatever your global `wrap`
  says, so set `wrap` per filetype instead.
- **Profiles switch:** `profiles = false` in `lua/user/config.lua` turns the
  writing and code profiles off, and `profiles = { classes = { tex = false } }`
  drops one filetype. If you cleared the `noethervim_profiles` augroup to
  turn them off, use `profiles = false` instead.
- **The code profile no longer turns `wrap` off:** a code buffer starts from
  your global `wrap`, and `[ow` in a code buffer stays on for that buffer.
- **Your keys stick:** every NoetherVim key, a lazily loaded plugin's
  included (ufo's `L`, dial's `<C-a>`, the test and debug keys), is mapped
  once at startup, before `lua/user/keymaps.lua`, and never again. A
  `vim.keymap.set` or `vim.keymap.del` there now lasts for the session; a
  key you redeclared on a plugin's spec only to make it stick can move back
  to `lua/user/keymaps.lua`.
- **Key sets:** `keymaps = { remaps = false }` in `lua/user/config.lua`
  gives `j`, `s`, `;`, `n` and every other key NoetherVim changes back
  their Vim meaning, and keeps the keys it adds; `keymaps = { lsp = false }`
  skips the keys mapped when a language server attaches.
- **Plugins no longer map their own keys:** nvim-surround,
  vim-visual-multi, marks.nvim, nvim-autopairs, vim-abolish, vim-repeat and
  smart-enter.nvim make no mappings of their own; NoetherVim maps the same
  keys. If you set `vim.g.VM_maps` yourself, it now replaces NoetherVim's.
- **Comment.nvim removed:** commenting is Neovim's built-in `gc`/`gcc`;
  `<C-/>` and `<C-S-r>` work as before. Block comments on `gb` are gone, as
  are `gco`, `gcO` and `gcA` (a comment below, above, or at the end of the
  line); add Comment.nvim from `lua/user/plugins/` if you used them.
- **`yP` (copy the compiled PDF) is a TeX-buffer key** in the latex
  bundle, no longer mapped everywhere once a TeX file has been opened.
- **With the yanky bundle,** visual `p` keeps the register as it does
  without the bundle, and normal `<C-n>` is yanky's next-entry key; start a
  multi-cursor session from a selection with visual `<C-n>`.
- **Your settings survive plugin loads:** a plugin's configuration no longer
  overwrites an option, global mapping or command you set. `timeoutlen`
  survives which-key loading, `wildchar` blink.cmp, `winwidth` windows.nvim,
  a `<leader>j` of yours LuaSnip. Nothing to do; `:NoetherVim where <key>`
  shows a NoetherVim mapping that stepped aside for yours.
- **Options at the top of `init.lua` are kept:** NoetherVim's defaults no
  longer replace an option set before `lazy.setup()`.
- **`NOETHERVIM_NO_USER=1` hides your whole config:** besides `lua/user/`,
  Neovim no longer sources your `plugin/`, `after/` and `ftplugin/` files,
  and your LuaSnip snippets, preamble library and spellfile are not read.
- **Colorscheme pick moved** to `stdpath("state")/noethervim/colorscheme`:
  pick your scheme with SearchLeader+C once more after updating.
- **Deadcolumn state moved** to `stdpath("state")/noethervim/deadcolumn`: if
  you had the guide off, press `]oG` once more.
- **Bundle plugins take your `opts`:** `opts` from a spec of yours now reach
  render-markdown, markdown-table-mode, betterTerm, nvim-luapad,
  distant.nvim, nvim-dap-virtual-text, nvim-dap-python and obsidian.nvim.
  For obsidian.nvim, `workspaces` in its `opts` wins over `obsidian_vault`;
  for drop.nvim, `themes` in its `opts` is now kept.
