# News

Breaking and behavior changes, newest first, each with what to do about it.
During the alpha, changes land without deprecation periods; this file is
where they are listed.

## 2026-10-29

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
  `<C-/>` and `<C-S-r>` work as before. Block comments on `gb` are gone; add
  Comment.nvim from `lua/user/plugins/` if you used them.
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
