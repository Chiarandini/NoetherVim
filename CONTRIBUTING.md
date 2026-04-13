# Contributing to NoetherVim

This guide explains NoetherVim's architecture, conventions, and how to
contribute. For the user-facing configuration reference, see `:help noethervim`.

## Table of Contents

- [Quick Start](#quick-start)
- [Architecture Overview](#architecture-overview)
  - [Directory Layout](#directory-layout)
  - [Boot Sequence](#boot-sequence)
  - [User Override System](#user-override-system)
- [Core Plugins](#core-plugins)
  - [Anatomy of a Plugin Spec](#anatomy-of-a-plugin-spec)
  - [The `opts` Contract](#the-opts-contract)
  - [Lazy-Loading](#lazy-loading)
- [Bundles](#bundles)
  - [What Is a Bundle?](#what-is-a-bundle)
  - [Anatomy of a Bundle](#anatomy-of-a-bundle)
  - [Creating a New Bundle](#creating-a-new-bundle)
  - [Bundle Checklist](#bundle-checklist)
- [Keybinding Conventions](#keybinding-conventions)
  - [Namespace Rules](#namespace-rules)
  - [Directional Navigation](#directional-navigation)
  - [Option Toggles](#option-toggles)
  - [Documenting Keymaps](#documenting-keymaps)
- [LSP Configurations](#lsp-configurations)
- [Statusline](#statusline)
- [Completion Sources](#completion-sources)
- [Filetype Plugins](#filetype-plugins)
- [Testing](#testing)
  - [Running Tests](#running-tests)
  - [Writing Tests](#writing-tests)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)

---

## Quick Start

Set up a development environment that doesn't touch your main Neovim config:

```bash
# Clone NoetherVim to a local directory
git clone https://github.com/Chiarandini/NoetherVim.git ~/programming/NoetherVim

# Create a dev config that points to your working copy
mkdir -p ~/.config/noethervim
cp ~/programming/NoetherVim/init.lua.example ~/.config/noethervim/init.lua
```

Edit `~/.config/noethervim/init.lua` and replace the NoetherVim spec with a
local path:

```lua
{
    "Chiarandini/NoetherVim",
    dir = "~/programming/NoetherVim",   -- use local checkout
    import = "noethervim.plugins",
    opts = { colorscheme = "gruvbox" },
    config = function(_, opts)
        require("noethervim").setup(opts)
    end,
},
```

Launch with:

```bash
NVIM_APPNAME=noethervim nvim
```

Changes to files in `~/programming/NoetherVim/lua/` take effect immediately
on the next Neovim restart (Lua modules are re-read from the rtp on startup).

---

## Architecture Overview

### Directory Layout

```
NoetherVim/
├── init.lua.example              # Starter template for the user's init.lua
├── lua/
│   └── noethervim/
│       ├── init.lua              # M.setup() — orchestrates all loading
│       ├── options.lua           # Core vim.o / vim.g settings
│       ├── keymaps.lua           # Core keymaps (all modes)
│       ├── autocmds.lua          # Core autocommands
│       ├── commands.lua          # User-facing :commands
│       ├── toggles.lua           # [o / ]o option toggle keymaps
│       ├── highlights.lua        # Highlight group overrides
│       ├── statusline.lua        # Statusline override registry
│       ├── inspect.lua           # :NoetherVim command family
│       ├── health.lua            # :checkhealth noethervim
│       ├── plugins/              # Core plugin specs (always loaded)
│       │   ├── lsp.lua
│       │   ├── cmp.lua           # blink.cmp configuration
│       │   ├── snacks.lua        # Dashboard, notifications, pickers
│       │   ├── statusline/       # Heirline statusline components
│       │   │   ├── init.lua      # Assembles all components
│       │   │   ├── vimode.lua
│       │   │   ├── git.lua
│       │   │   ├── diagnostics.lua
│       │   │   └── ...
│       │   └── ...
│       ├── bundles/              # Opt-in plugin groups (36 bundles)
│       │   ├── latex.lua
│       │   ├── git.lua
│       │   └── ...
│       ├── lsp/                  # Per-server LSP configurations
│       │   ├── lua_ls.lua
│       │   ├── basedpyright.lua
│       │   └── ...
│       ├── sources/              # Custom blink.cmp completion sources
│       │   ├── todos.lua
│       │   └── images.lua
│       └── util/                 # Internal utilities
│           ├── init.lua          # search_leader, distro_root
│           ├── icons.lua
│           ├── palette.lua
│           └── ...
├── ftplugin/                     # Filetype-specific settings
├── templates/user/               # Example files for user overrides
├── queries/                      # Treesitter queries (markdown)
├── doc/noethervim.txt            # Vimdoc (:help noethervim)
├── tests/                        # Test suite
└── tools/                        # Install script
```

**Important:** `lua/user/` must NOT exist in this repository. lazy.nvim's
`find_root()` returns only the first matching directory on the rtp. If the
repo has `lua/user/plugins/`, lazy.nvim scans that instead of the user's
config directory, making all user plugin specs invisible.

Template files live in `templates/user/` (outside `lua/`, never on the rtp).

### Boot Sequence

When the user starts Neovim with NoetherVim's `init.lua`:

```
User's init.lua
│
├─ 1. Set leaders (mapleader, maplocalleader, mapsearchleader)
├─ 2. Bootstrap lazy.nvim (clone if missing)
├─ 3. Bootstrap NoetherVim (clone if missing)
└─ 4. require("lazy").setup({
       spec = {
         { "Chiarandini/NoetherVim",
           import = "noethervim.plugins",  -- auto-imports all core specs
           opts = { ... },
           config = function(_, opts)
             require("noethervim").setup(opts)  -- see below
           end,
         },
         { import = "noethervim.bundles.latex" },   -- user picks bundles
         { import = "noethervim.bundles.git" },
         { import = "user.plugins" },               -- user plugin overrides
       },
     })
```

lazy.nvim resolves and merges all specs, installs missing plugins, then calls
each plugin's `config` function. NoetherVim's `M.setup(opts)` runs as part
of this and orchestrates core loading:

```
M.setup(opts)
│
├─ Determine whether to load user overrides
│    (NOETHERVIM_NO_USER=1 or vim.g.noethervim_no_user skips them)
│
├─ Forward statusline overrides (opts.statusline)
├─ Disable unused providers (ruby, perl, node)
│
├─ Load core modules (each followed by user override):
│    options.lua    → user.options
│    keymaps.lua    → user.keymaps     (with before/after snapshots)
│    toggles.lua
│    autocmds.lua   → user.autocmds
│    commands.lua
│    highlights.lua → user.highlights
│
├─ Load LSP configs:
│    noethervim/lsp/*.lua → user/lsp/*.lua
│
├─ Apply colorscheme (with optional persistence)
│
├─ Load imperative user overrides (user/overrides/*.lua)
│
└─ Initialize inspection commands
```

The key insight: **user modules load immediately after their core
counterparts**. Since Neovim uses last-write-wins semantics for options,
keymaps, and highlights, user settings naturally override core defaults
with zero framework code.

### User Override System

Contributors should understand the override system because every core module
must be designed to be overridable. The levels are:

| Level | Mechanism | When it runs |
|-------|-----------|-------------|
| `user/options.lua` | `pcall(require, "user.options")` | After core options |
| `user/keymaps.lua` | `pcall(require, "user.keymaps")` | After core keymaps + toggles |
| `user/plugins/*.lua` | lazy.nvim spec merging | During spec resolution (before setup) |
| `user/lsp/*.lua` | `vim.lsp.config()` deep-merge | After core LSP configs |
| `user/autocmds.lua` | `pcall(require, "user.autocmds")` | After core autocmds |
| `user/highlights.lua` | `pcall(require, "user.highlights")` | After colorscheme |
| `user/overrides/*.lua` | `pcall(require)` scan | Last (escape hatch) |

**The practical implication for contributors:** when adding a new option,
keymap, or highlight to a core module, it is automatically overridable by the
user. No special handling is needed. For plugin configuration, put data into
`opts` (not hardcoded in `config`) so users can override via lazy.nvim spec
merging.

---

## Core Plugins

Core plugins live in `lua/noethervim/plugins/`. They are always loaded
(imported via `import = "noethervim.plugins"` in the user's `init.lua`).

### Anatomy of a Plugin Spec

Every file in `plugins/` returns a table of lazy.nvim specs:

```lua
-- lua/noethervim/plugins/example.lua
return {
    {
        "author/plugin.nvim",
        event = "BufReadPost",           -- lazy-load trigger
        opts = {                         -- overridable configuration data
            option_a = true,
            option_b = { nested = "value" },
        },
        config = function(_, opts)       -- receives merged opts
            require("plugin").setup(opts)
            -- imperative logic that can't live in opts goes here
        end,
    },
}
```

### The `opts` Contract

This is a core architectural rule:

> **All configurable data must live in `opts`, not hardcoded in `config`.**

lazy.nvim deep-merges `opts` tables when multiple specs target the same
plugin. This means a user can write:

```lua
-- user/plugins/example.lua
return {
    { "author/plugin.nvim", opts = { option_a = false } },
}
```

And only `option_a` changes — everything else is preserved. If the data is
hardcoded inside `config = function()`, the user must replace the entire
`config` function to change a single value.

**Pattern for mixed data + logic:**

```lua
opts = {
    ensure_installed = { "lua_ls", "basedpyright" },  -- data (overridable)
    diagnostic = { virtual_text = false },             -- data (overridable)
},
config = function(_, opts)
    -- Logic that MUST be imperative (not overridable via opts)
    require("mason").setup({})
    require("mason-lspconfig").setup({
        ensure_installed = opts.ensure_installed,      -- reads from merged opts
    })
    vim.diagnostic.config(opts.diagnostic)             -- reads from merged opts
end,
```

### Lazy-Loading

Every plugin should be lazy-loaded unless it must run at startup. Common
triggers:

| Trigger | Use when |
|---------|----------|
| `event = "BufReadPost"` | Plugin needs buffer content (treesitter, folding, marks) |
| `event = "InsertEnter"` | Insert-mode plugins (autopairs, completion) |
| `event = "VeryLazy"` | Visual plugins that don't need to be instant |
| `cmd = "CommandName"` | Plugin provides commands the user invokes explicitly |
| `keys = { ... }` | Plugin is only needed when specific keys are pressed |
| `ft = "filetype"` | Filetype-specific plugins |
| `lazy = false` | Plugin MUST load at startup (snacks, oil, colorscheme) |

**`lazy = false` requires justification.** The only core plugins that load
eagerly are: snacks.nvim (dashboard, UI primitives), oil.nvim (replaces
netrw), and colorschemes.

---

## Bundles

### What Is a Bundle?

A bundle is an opt-in group of related plugins. Users enable them by
uncommenting an `import` line in their `init.lua`:

```lua
{ import = "noethervim.bundles.git" },
```

Bundles live in `lua/noethervim/bundles/`. Each file returns a table of
lazy.nvim specs, just like core plugins.

### Anatomy of a Bundle

```lua
-- lua/noethervim/bundles/my-bundle.lua

-- NoetherVim bundle: Short Name
-- Enable with: { import = "noethervim.bundles.my-bundle" }
--
-- Provides:
--   plugin-a:   one-line description of what it does
--   plugin-b:   one-line description of what it does
--
-- Keymaps:
--   <Leader>xf     Description of what this does
--   <Leader>xg     Description of what this does
--   <LocalLeader>r Description (filetype-specific, buffer-local)

local SearchLeader = require("noethervim.util").search_leader

return {
    {
        "author/plugin-a.nvim",
        cmd = "PluginCommand",
        keys = {
            { "<Leader>xf", function() ... end, desc = "do [f]oo" },
        },
        opts = { ... },
    },
    {
        "author/plugin-b.nvim",
        ft = "specific_filetype",
        opts = { ... },
    },
}
```

**Header comment block:** Every bundle MUST have a header that lists:
1. What plugins the bundle provides (with one-line descriptions)
2. All keymaps the bundle registers

This is the canonical reference for bundle keymaps. Users discover them via
`<Space>fk` (search keymaps) or `<Space>ck` (diff keymaps), and contributors
find them in the header.

### Creating a New Bundle

1. Create `lua/noethervim/bundles/my-bundle.lua` following the anatomy above.

2. Add an entry to the `bundle_catalog` table in `lua/noethervim/inspect.lua`:

   ```lua
   { name = "my-bundle", cat = "Tools", desc = "short description" },
   ```

   Valid categories: `Languages`, `Tools`, `Navigation`, `Writing`,
   `Terminal`, `UI`, `Practice`.

3. Add a commented-out import line to `init.lua.example` under the matching
   category:

   ```lua
   -- { import = "noethervim.bundles.my-bundle" }, -- short description
   ```

4. Add the bundle to the table in `README.md` under the matching category.

5. Add a brief entry in `doc/noethervim.txt` under `*noethervim-bundles*`.

6. If the bundle adds keymaps in the `<Space>` (SearchLeader) namespace,
   register a which-key group in `lua/noethervim/plugins/whichkey.lua`.

### Bundle Checklist

Before merging a bundle, verify:

- [ ] **Self-contained.** Disabling the bundle causes zero errors. No core
      plugin depends on the bundle being present.
- [ ] **Dependencies declared.** All plugin dependencies are listed in the
      `dependencies` field of the spec, not assumed to be available.
- [ ] **Keybindings follow conventions.** See [Keybinding Conventions](#keybinding-conventions).
      `<LocalLeader>` mappings are buffer-local. No conflicts with core or
      other bundles.
- [ ] **No personal content.** No hardcoded paths, author-specific tool
      configs, or locale-dependent logic.
- [ ] **Cross-platform.** No macOS-only commands (`open`) without a
      Linux/Windows fallback. Use `vim.ui.open()` (Neovim 0.10+) for URLs
      and files.
- [ ] **Properly lazy-loaded.** Every plugin has an appropriate trigger.
- [ ] **`opts` contract honored.** Configurable values are in `opts`, not
      hardcoded in `config`.
- [ ] **Header comment complete.** Lists all plugins and all keymaps.
- [ ] **Catalog updated.** Entry in `inspect.lua`, `init.lua.example`,
      `README.md`, and `doc/noethervim.txt`.

---

## Keybinding Conventions

### Namespace Rules

NoetherVim enforces a strict keybinding philosophy. Every keymap must belong
to one of these namespaces:

| Prefix | Purpose | Examples |
|--------|---------|---------|
| SearchLeader (default `<Space>`) | Fuzzy navigation and search ONLY | `<Space>ff` find files, `<Space>lg` live grep |
| `<Leader>` (default `\`) | Global actions | `\ff` format, `\rd` generate docstring |
| `<LocalLeader>` (default `,`) | Filetype-specific actions | `,ll` compile LaTeX, `,r` run REPL line |
| `<C-w>` | ALL window/tab/split manipulation | `<C-w>z` maximize, `<C-w><C-d>` toggle DAP |
| `[` / `]` | Directional: previous / next | `[d` prev diagnostic, `]b` next buffer |
| `[o` / `]o` | Toggle option: on / off | `[os` spell on, `]os` spell off |

**Rules:**

1. **SearchLeader keymaps must be pure navigation/search.** No side effects,
   no mutations. If it changes state, it belongs under `<Leader>`.

2. **`<LocalLeader>` keymaps must be buffer-local.** They are for
   filetype-specific actions. Setting a global `<LocalLeader>` keymap is a
   bug. Use `vim.keymap.set("n", "<LocalLeader>x", ..., { buffer = bufnr })`
   or scope via `ft` in the lazy spec.

3. **Window operations use `<C-w>`.** Opening splits, tabs, resizing,
   maximizing, closing — all under `<C-w>`.

4. **Use SearchLeader from `util`.** Never hardcode `<Space>` for search
   keymaps. The search leader is configurable:
   ```lua
   local SearchLeader = require("noethervim.util").search_leader
   keys = {
       { SearchLeader .. "xf", function() ... end, desc = "[x] [f]eature" },
   },
   ```

5. **Don't override fundamental Vim operations** without strong justification.
   `c` (change), `d` (delete), `y` (yank), `p` (paste), `gv` (reselect),
   `.` (repeat) — these are sacred. Overriding them creates a distribution
   that doesn't feel like Vim.

   NoetherVim's existing overrides of `J` (scroll down), `K` (scroll up in
   normal; join+reflow in visual), `L` (fold peek / hover), and `S` (global
   substitute) are documented in the vimdoc under the "Shadowed defaults"
   section. Any new override of a standard Vim key must be documented there.

### Directional Navigation

The `[` / `]` prefix denotes movement:

| Pattern | Meaning |
|---------|---------|
| `[x` | Go to previous x |
| `]x` | Go to next x |
| `[X` | Go to first x |
| `]X` | Go to last x |

Examples: `[d`/`]d` (diagnostic), `[b`/`]b` (buffer), `[t`/`]t` (tab),
`[e`/`]e` (move line up/down), `[c`/`]c` (git hunk).

**Do not use `[x`/`]x` for toggles.** Toggles use `[o`/`]o`.

### Option Toggles

| Pattern | Meaning |
|---------|---------|
| `[o<x>` | Enable option x |
| `]o<x>` | Disable option x |

Examples: `[os`/`]os` (spell), `[ow`/`]ow` (wrap), `[oL`/`]oL` (LSP).

New toggles go in `lua/noethervim/toggles.lua` using the `toggle()` helper:

```lua
toggle("o<key>",
  "<cmd>setlocal spell<cr>",         -- enable rhs
  "<cmd>setlocal nospell<cr>",       -- disable rhs
  "spell")                            -- description
```

### Documenting Keymaps

Every keymap should have a `desc` field. Use mnemonic brackets in
descriptions to show the key derivation:

```lua
{ SearchLeader .. "ff", ..., desc = "[f]ind [f]iles" },
{ "<Leader>rd",         ..., desc = "[r]efactor: generate [d]ocstring" },
```

Keymaps are discoverable through:
- **which-key:** Press any prefix and wait for the popup.
- **`<Space>fk`:** Search all keymaps by description.
- **`<Space>ck`:** Smart diff picker showing core vs user keymaps.

---

## LSP Configurations

Per-server configs live in `lua/noethervim/lsp/`. Each file calls
`vim.lsp.config()`:

```lua
-- lua/noethervim/lsp/lua_ls.lua
vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            diagnostics = { globals = { "vim" } },
        },
    },
})
```

`vim.lsp.config()` deep-merges when called multiple times for the same
server. This means:
- Core config sets base settings
- User config in `user/lsp/lua_ls.lua` adds or overrides specific fields
- No explicit merge code is needed

**Adding a new server:**

1. Create `lua/noethervim/lsp/<server>.lua` with the config.
2. Add the server name to `ensure_installed` in `plugins/lsp.lua` opts.
3. The server file is auto-discovered by scanning
   `lua/noethervim/lsp/*.lua` on the rtp.

---

## Statusline

The statusline uses heirline.nvim, split across
`lua/noethervim/plugins/statusline/`:

| File | Contents |
|------|----------|
| `init.lua` | Assembles all components into statusline, winbar, tabline |
| `vimode.lua` | Vi mode indicator with colors |
| `git.lua` | Branch name, diff counts, click to lazygit |
| `diagnostics.lua` | Error/warn/info/hint counts |
| `filename.lua` | Project-relative file path, modified indicator |
| `lsp.lua` | Active LSP server names |
| `ruler.lua` | Line:column position |
| `tabline.lua` | Tab pages with file icons |
| `winbar.lua` | Breadcrumb navigation |
| `context.lua` | Shared color palette and helpers |
| `misc.lua` | Spacers, separators, alignment |
| `bundle_extras.lua` | Components from bundles (VimTeX compiler status) |
| `keymaps.lua` | Statusline toggle keymaps (`<C-w>s` prefix) |

**User customization** is handled via `opts.statusline` in the NoetherVim
spec:

```lua
opts = {
    statusline = {
        colors = { mode_n = "#458588" },  -- override normal-mode color
        extra_right = { MyComponent },     -- add heirline components
    },
},
```

The override registry lives in `lua/noethervim/statusline.lua`. For details
on writing heirline components, see `:help heirline-cookbook`.

---

## Completion Sources

Custom blink.cmp sources live in `lua/noethervim/sources/`. Each source
module must implement the blink.cmp source interface:

```lua
-- lua/noethervim/sources/example.lua
local M = {}

function M.new()
    return setmetatable({}, { __index = M })
end

function M:get_completions(ctx, callback)
    local items = {}
    -- Build completion items...
    callback({ items = items, is_incomplete_forward = false })
end

return M
```

Sources are registered in `plugins/cmp.lua` under the `sources.providers`
table and referenced in `sources.default` or `sources.per_filetype`.

---

## Filetype Plugins

Filetype-specific settings go in `ftplugin/<filetype>.lua`. These run
automatically when a buffer of that filetype is opened.

**Key rules:**

- Use `vim.bo` for buffer options, `vim.wo` for window options. Note that
  `wrap` and `conceallevel` are **window-local** (`vim.wo`), not buffer-local.
- All keymaps must be buffer-local: `vim.keymap.set("n", ..., { buffer = true })`.
- Include a header comment: `-- NoetherVim ftplugin: <filetype>`.

---

## Testing

### Running Tests

Tests live in `tests/` and are run headlessly:

```bash
# Run a single test
NVIM_APPNAME=noethervim nvim --headless -l tests/test_blink_config.lua

# Run all tests
bash tests/run.sh
```

Most tests require a fully bootstrapped NoetherVim instance (plugins
installed, config loaded). Only pure-function tests (e.g.,
`test_gd_label.lua`) can run in a minimal `nvim -u NONE` environment.

### Writing Tests

Tests use a lightweight `ok(name, cond, msg)` helper:

```lua
-- tests/test_my_feature.lua
local pass, fail = 0, 0
local function ok(name, cond, msg)
    if cond then
        pass = pass + 1
        print("PASS: " .. name)
    else
        fail = fail + 1
        print("FAIL: " .. name .. (msg and (" -- " .. msg) or ""))
    end
end

-- Test cases
ok("option is set", vim.o.number == true)
ok("keymap exists",
    vim.fn.maparg("<Space>ff", "n") ~= "",
    "expected <Space>ff to be mapped")

-- Report and exit
print(string.format("\n%d passed, %d failed", pass, fail))
vim.cmd("cq" .. (fail > 0 and "1" or "0"))
```

**What to test (high ROI):**

| Tier | What | Example |
|------|------|---------|
| Pure functions | Utility functions with no Neovim deps | Image path parsing, URL matching |
| Config validation | Inspect loaded state after bootstrap | Keymap conflicts, option values, spec validity |
| Smoke tests | Core mechanisms end-to-end | Bundle enable/disable, user overrides, colorscheme persistence |

**What NOT to test:**
- Individual plugin UIs (completion menu rendering, picker behavior)
- LSP server responses (requires running language servers)
- Timing-dependent cross-plugin interactions

---

## Code Style

**Lua:**
- Use `local` for all variables. No implicit globals.
- Prefer `vim.keymap.set()` over `vim.cmd("map ...")`.
- Prefer `vim.api.nvim_set_hl()` over `vim.cmd("hi ...")`.
- Prefer `vim.notify()` over `vim.cmd('echom "..."')`.
- Use `vim.opt:append()` for list-type options (diffopt, shortmess), not
  string concatenation.
- Require external modules explicitly: `local Snacks = require("snacks")`,
  not bare globals.

**Naming:**
- Plugin spec files: lowercase with hyphens (`git-setup.lua`, not
  `gitSetup.lua`).
- Bundle files: lowercase with hyphens, named for the feature domain
  (`debug.lua`, `eye-candy.lua`).
- LSP files: match the server name exactly (`lua_ls.lua`, `basedpyright.lua`).

**Comments:**
- Every plugin spec file should have a header comment block explaining what
  it configures.
- Every bundle should list its plugins and keymaps in the header (see
  [Anatomy of a Bundle](#anatomy-of-a-bundle)).
- Inline comments for non-obvious logic. Don't comment obvious code.

**Keymaps:**
- Always include a `desc` field.
- Use mnemonic bracket notation: `desc = "[f]ind [f]iles"`.
- Buffer-local keymaps: `{ buffer = bufnr }` or `{ buffer = true }`.

---

## Submitting Changes

1. **Check existing issues** before starting work. If there isn't one, open
   an issue describing what you want to change and why.

2. **Fork and branch.** Create a feature branch from `main`.

3. **Follow the conventions** documented above. The most common review
   feedback is:
   - Keymaps missing `desc` fields
   - `<LocalLeader>` keymaps set globally instead of buffer-local
   - Data hardcoded in `config` instead of `opts`
   - Missing bundle catalog entries
   - Missing cross-platform support

4. **Test your changes.** At minimum:
   - Start Neovim fresh and verify no errors
   - If you changed a bundle, test with the bundle enabled AND disabled
   - If you added keymaps, check for conflicts with `<Space>fk`
   - Run `:checkhealth noethervim`

5. **Open a pull request** with:
   - A clear description of what changed and why
   - Which files were modified
   - How you tested the changes

**Scope guidelines:**
- Bug fixes: go ahead, keep it focused.
- New bundles: open an issue first to discuss whether it fits.
- Core plugin changes: open an issue first — these affect all users.
- Keymap changes: open an issue first — namespace conflicts are common.
