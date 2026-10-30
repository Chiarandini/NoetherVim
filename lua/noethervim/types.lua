--- LuaCATS type declarations for NoetherVim's public API.
---
--- This file has no runtime effect -- it exists so that `lua-language-server`
--- (via `.luarc.json` or `lazydev.nvim`) can offer completion and type
--- diagnostics on the single user-facing surface:
---
---     The data table returned from `lua/user/config.lua`.
---
--- Internal types live next to the modules that use them, with `---@private`
--- annotations on internal helpers.
---
--- FORMATTING RULE, load-bearing: each `@field`'s entire description must sit
--- on the same physical line as the tag. lua-language-server binds a `---`
--- continuation line to the NEXT tag rather than the one above it, so a
--- wrapped description silently becomes the following field's documentation
--- and every field ends up describing its neighbour. Text on preceding lines
--- fails the same way. Do not reflow this file for line length; keep the
--- prose tight instead.
---
--- Stability: alpha. See dev-docs/architecture.md §1.1 for the deprecation
--- policy. Field renames before the first non-alpha release land directly,
--- without `vim.deprecate` shims.

---@class noethervim.Row
---@field [1] string lhs
---@field [2] string|fun():any|false rhs; false removes the row with the same identity
---@field owner? string lazy.nvim name of the plugin the row belongs to; skipped when that plugin is absent or its keys hold { lhs, false }
---@field mode? string|string[] default "n"
---@field desc? string shown by which-key, :NoetherVim where and the keymap guide
---@field set? string key set ("remaps", "lsp", ...) that `keymaps` in lua/user/config.lua can switch off
---@field ft? string|string[] buffer-local in these filetypes, mapped on FileType; a buffer mapping of yours wins
---@field lsp? string|true LSP method the attached server must support, or true; buffer-local on LspAttach
---@field expr? boolean passed to vim.keymap.set
---@field silent? boolean passed to vim.keymap.set
---@field remap? boolean passed to vim.keymap.set
---@field nowait? boolean passed to vim.keymap.set
---@field _source? string `file:line` of the declaration, for rows mapped from core files

---@class noethervim.ProfilesConfig
---@field classes? table<string, "writing"|"code"|false> Per filetype: the profile it gets, or `false` for none.
---@field spell_in_code? boolean If true, the code profile enables spellcheck, scoped to comments and strings via treesitter `@spell` captures so identifiers are not flagged. Default: false.
---@field conservative? noethervim.ConservativeConfig Where completion waits to be asked instead of opening as you type.

---@alias noethervim.ConservativeConfig table<string, boolean|integer> `[ft] = true` makes completion wait to be asked in that filetype, `false` stops it (tex and latex wait by default); `size_kb` (default 500) makes it wait in any file larger than that.

---@class noethervim.CompletionConfig
---@field style? "snippet"|"supertab"|"navigate" Tab-key philosophy for the completion menu. `"snippet"` reserves Tab for LuaSnip, `"supertab"` accepts the menu item, `"navigate"` cycles the menu without accepting. Default: `"snippet"`.

---@class noethervim.HostOpts
---@field rows? noethervim.Row[] distro mappings, appended by each spec through rows.contribute()
---@field g? table<string, any> plugin globals set at startup when still nil
---@field startup? table<string, fun()|false> registrations that must exist from startup, run in id order
---@field gutter? table<string, fun(ctx: noethervim.GutterClick)|false> what clicking a sign does, keyed by a Lua pattern matched against the sign name
---@field segments? table<string, noethervim.Segment|false> statusline segments by id (noethervim.statusline)
---@field busy? table<string, noethervim.Busy|false> what fills the statusline's busy slot, by id

---@class noethervim.StatuslineConfig
---
--- The `statusline` table in lua/user/config.lua.
---
---@field style? noethervim.StatuslineStyle How heirline draws the bars. Inert with heirline switched off.
---@field segments? table<string, noethervim.Segment|false> Segments of yours by id, or in place of a unit's with the same id.
---@field layout? table<string, boolean|{ side?: "left"|"right", after?: string }> Per block or segment id: `true` shows it from the start, `false` hides it, a table moves it.
---@field bars? { statusline?: boolean, tabline?: boolean, winbar?: boolean } `false` leaves that bar to Neovim (or to another plugin).

---@class noethervim.StatuslineStyle
---@field colors? table<string, string> Heirline color-table overrides. Keys match the palette's names (e.g. `mode_n`, `green`, `profile_code`); values are hex strings.
---@field edge_style? "round"|"slant"|"slant_left"|"slant_in"|"slant_out"|"pointy"|"straight"|"bubbly" Shape of the colored mode block at the left of the statusline, and (for "bubbly", "slant", "pointy") an opening endcap on the right ruler block. Default "round"; "bubbly" rounds both edges; "straight" disables endcaps entirely.
---@field tab_modified_indicator? string Glyph shown on a tab containing unsaved changes. Default `" ●"`. Common alternatives: `" [+]"` (vim default), `" *"`, `" ◉"`. A leading space separates it from the tab's filename.
---@field mode_background? boolean If false, the statusline keeps one background in every mode instead of shifting to blue in insert. The mode chip still changes colour. Default: true.
---@field git_click? fun() Called when the git block is clicked. The default opens lazygit when it is on PATH and falls back to snacks' git-status picker otherwise.

---@class noethervim.Segment
---@field provider fun(ctx: noethervim.SegmentCtx): string|{ [1]: string, [2]: (string|table)? }[]|nil Text, or chunks of text each with a highlight group name or a `{ fg = ... }` table; nil or "" shows nothing.
---@field cond? fun(ctx: noethervim.SegmentCtx): boolean Shown only where this returns true.
---@field click? fun(ctx: noethervim.SegmentCtx, button: string) Called on a click, with "l", "m" or "r".
---@field hl? string|table Highlight for a provider that returns plain text.
---@field place? { side?: "left"|"right", after?: string } Where heirline puts it: after a block or segment id, else at the start of its side (default "right").

---@class noethervim.SegmentCtx
---@field win integer
---@field buf integer

---@alias noethervim.Busy fun(): true|{ icon?: string, label?: string, hl?: table, click?: fun() }|nil

---@class noethervim.DisabledSnippet
---
--- One snippet you never want offered, named durably enough to survive a
--- restart and to still mean the same snippet on another machine.
---
---@field ft string Filetype the snippet is registered under, as shown in the snippet picker's second column. `"all"` means every buffer type.
---@field trigger string The trigger, exactly as defined. Triggers repeat on purpose, so this alone names nothing; the owner and file finish the job.
---@field owner string Who ships the file: a plugin name as lazy.nvim knows it, or `"config"` for a file in your own `LuaSnip/` tree.
---@field file string Path to the defining file inside that owner, never absolute, so the entry survives being copied to a machine that puts plugins elsewhere.
---@field line? integer Line the snippet starts on. Consulted only when two snippets share a trigger in one file, and re-checked rather than trusted, so it does not need keeping current.

---@class noethervim.UserConfig
---
--- The data table returned from `lua/user/config.lua`: everything
--- NoetherVim itself lets you change about its behaviour.
---
--- Every field is optional. Missing keys fall back to distro defaults.
---
---@field colorscheme? string Colorscheme applied at startup, unless a scheme picked interactively with SearchLeader+C has been restored over it. Defaults to `"gruvbox"`, the shipped theme; the dashboard and statusline fallback colours are chosen to match it. A name that is not installed warns and falls back to gruvbox.
---@field colorscheme_persistence? boolean If true, restore the last interactively picked colorscheme on startup, in preference to `colorscheme`. Set false to make `colorscheme` authoritative. Default: true.
---@field statusline? noethervim.StatuslineConfig The statusline: segments and their layout by id, the bars drawn, and heirline's look.
---@field completion? noethervim.CompletionConfig How the completion menu takes Tab.
---@field q_close? table<string, boolean> Filetypes where a bare `q` closes the window: `true` adds one, `false` removes one of the defaults. Editable filetypes (`oil`, `markdown`, ...) are left out by default because `q` there shadows macro recording.
---@field profiles? false|noethervim.ProfilesConfig `false` turns the writing and code profiles off. `classes` moves a filetype to "writing" or "code", or leaves it alone with `false`; `spell_in_code` and `conservative` tune the profiles.
---@field lsp? table<string, false> `[name] = false` drops NoetherVim's settings for that server (after/lsp/<name>.lua); lspconfig's and yours remain.
---@field toggle_feedback? "notify"|"echo"|"off" Channel for the confirmation message emitted when a bracket-prefix toggle (`[ox` / `]ox`) fires. `"notify"` (default) routes through `vim.notify`, which snacks renders as a toast; `"echo"` uses `nvim_echo` for the classic cmdline message; `"off"` suppresses it.
---@field snippets_disabled? noethervim.DisabledSnippet[] Snippets to keep switched off wherever this config is used. The snippet picker (`:NoetherVim snippets`, or SearchLeader+cs) copies a correct entry to your clipboard with `<C-o>`, filling in the owner and file. `<C-x>` there switches one off on this machine only, and that choice wins over this list for the session.
---@field keymaps? table<string, boolean> Key sets to switch off. `remaps = false` keeps every key whose Vim meaning NoetherVim changes (`;`, `s`, `n`, ... as Vim has it, while keeping NoetherVim's added keys; `lsp = false` skips the keys mapped when a language server attaches.

return {}
