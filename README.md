# NoetherVim

A Neovim distribution with a minimal abstraction layer. The name is after [Emmy Noether](https://en.wikipedia.org/wiki/Emmy_Noether) (the name also contains *nvim* - *noether**Vim***).

LaTeX, BibTeX, and VimTeX get the same level of support as LSP and treesitter. Everything else you'd expect is configured out of the box: completion (blink.cmp), DAP, diagnostics, formatters. Startup is fast by using lazy-loading.

The distro is opinionated, but anything can be overridden through `lua/user/` without forking or editing distro files (see [Configuration](#configuration))

> [!NOTE]
> NoetherVim is in **alpha**. The core is stable for daily use, but what counts as a "default" vs. an "overridable" option is still being refined. These choices grew out of my Neovim use and represent my best idea of good, agnostic defaults. If you think there are better choices, [open an issue](https://github.com/Chiarandini/NoetherVim/issues) and we can address it there.

## Why another distribution?

Existing Neovim distributions introduce their own abstraction layers: framework APIs,
custom event systems, declarative config DSLs, etc. These are powerful, but they sit
between you and Neovim; your configuration ends up targeting the distribution, not the
editor.

NoetherVim takes a different approach: plugin specs are standard lazy.nvim, options are
`vim.o`, keymaps are `vim.keymap.set()`, and so forth. Overriding a default means writing
the same Lua you would write in a vanilla Neovim config, and the distro just makes sure
your file loads after its own.

The same principle applies to keybindings. Keymaps build on Vim's own prefix conventions
rather than funneling everything through `<Leader>` subgroups: `<C-w>` for anything
window-related (panels, terminal, undo tree), `[`/`]` for directional navigation,
`[o`/`]o` for option toggles, `g` for goto and LSP actions. `<Leader>` and `<LocalLeader>`
stay separate (global actions vs. filetype-specific), following `:help maplocalleader`.
Features use Neovim's built-in APIs directly (`vim.lsp.config()`, `vim.diagnostic`,
`vim.fn.setqflist()`) and where Neovim 0.12 ships good defaults, the distro leaves them
alone.

Also, after using vim/nvim for ~10 years, my nvim dotfiles have grown to be 5000+ lines of
code. So this is partly a fun project to convert the core functionality of my personal
setup into a distribution.

## Requirements

- Neovim >= 0.12
- A [Nerd Font](https://www.nerdfonts.com/) for icons
- `git`, `fd`, `ripgrep`, a C compiler (for treesitter parsers)

<details>
<summary>Neovim: Platform install commands</summary>

**macOS**
```bash
brew install neovim ripgrep fd
```

**Ubuntu / Debian**
> `apt install neovim` ships an outdated version on most releases.
> Use the [Neovim PPA](https://github.com/neovim/neovim/blob/master/INSTALL.md#ubuntu),
> an [AppImage](https://github.com/neovim/neovim/releases), or
> [bob](https://github.com/MordechaiHadad/bob) to get Neovim >= 0.12.
```bash
sudo apt install ripgrep fd-find
```

**Arch**
```bash
sudo pacman -S neovim ripgrep fd
```

**Fedora**
```bash
sudo dnf install neovim ripgrep fd-find
```

</details>

Some bundles have their own dependencies:
- `latex` needs `latexmk` and a TeX distribution
- `debug` needs Python 3 with `debugpy` for Python debugging
- `ai` needs an API key (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc.)

## Installation

> [!IMPORTANT]
> If you have an existing Neovim config, **back it up first**:
> ```bash
> mv ~/.config/nvim ~/.config/nvim.bak
> mv ~/.local/share/nvim ~/.local/share/nvim.bak
> mv ~/.local/state/nvim ~/.local/state/nvim.bak
> mv ~/.cache/nvim ~/.cache/nvim.bak
> ```

Copy the starter config and open Neovim:

```bash
mkdir -p ~/.config/nvim
curl -fLo ~/.config/nvim/init.lua \
  https://raw.githubusercontent.com/Chiarandini/NoetherVim/main/init.lua.example
nvim
```

On first launch, lazy.nvim bootstraps itself, pulls all plugins, and runs `noethervim.setup()`.

> [!TIP]
> **Want to try NoetherVim without replacing your config?** Neovim's `NVIM_APPNAME` feature lets you run multiple configs side by side:
> ```bash
> mkdir -p ~/.config/noethervim
> curl -fLo ~/.config/noethervim/init.lua \
>   https://raw.githubusercontent.com/Chiarandini/NoetherVim/main/init.lua.example
> NVIM_APPNAME=noethervim nvim
> ```
> Your existing `~/.config/nvim/` stays untouched. Add `alias nv='NVIM_APPNAME=noethervim nvim'` to your shell profile for convenience.

### Updating

Run `:Lazy update` inside Neovim. This updates the distro and all plugins.

### Uninstalling

The following are important files/locations for a Neovim setup:

| Path | Contents |
|---|---|
| `~/.config/nvim/init.lua` | Your leaders and bundle selection |
| `~/.config/nvim/lua/user/` | Your plugin specs, option/keymap/autocmd overrides |
| `~/.config/nvim/lazy-lock.json` | Your pinned plugin versions |
| `~/.local/state/nvim/` | Shada (command/search history, marks, registers), undo history, sessions, views |
| `~/.local/share/nvim/site/spell/` | Custom spell additions |

Everything else under `~/.local/share/nvim/` and `~/.cache/nvim/` is installed or generated by the distro and can be regenerated by relaunching Neovim.

**Reset the distribution, keep personal data.** Wipes installed plugins (lazy.nvim, NoetherVim, everything else), Mason-managed LSP servers and formatters, and all caches. Your `init.lua`, `lua/user/`, and editing state (history, undo, sessions) stay intact. Next launch re-bootstraps and reinstalls everything from scratch.

```bash
rm -rf ~/.local/share/nvim ~/.cache/nvim
```

**Reset the distribution and editing state.** Same as above but also drops shada, undo history, sessions, and views. Config is still preserved.

```bash
rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
```

**Full uninstall.** Removes the config, data, state, and cache directories. Restore your backup if you made one.

```bash
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
```

> [!TIP]
> If you installed with `NVIM_APPNAME=noethervim`, substitute `noethervim` for `nvim` in every path above.

### Migrating from an existing config

Back up your current `~/.config/nvim/` before installing. NoetherVim replaces `init.lua`, so anything there will be overwritten.

Once you're running, you can bring over your personal settings:
- **Plugins** - add lazy.nvim specs to `lua/user/plugins/` (see [Configuration](#configuration))
- **Options/keymaps/autocmds** - most of these already have NoetherVim equivalents; check what the distro sets before re-adding
- **LSP configs** - NoetherVim configures servers through `lua/noethervim/lsp/`; if you had custom server settings, look there first

## Configuration

### Enabling bundles

Open `~/.config/nvim/init.lua` and uncomment the bundles you want in the `spec` table:

```lua
-- inside require("lazy").setup({ spec = { ... } })
{ import = "noethervim.bundles.latex" },
{ import = "noethervim.bundles.debug" },
{ import = "noethervim.bundles.git" },
```

All bundles are opt-in - the core is fully functional with none enabled. See [Bundles](#bundles) for the full list.

### Adding your own plugins

Drop plugin specs in `~/.config/nvim/lua/user/plugins/`. Any `.lua` file there is auto-imported by lazy.nvim:

```lua
-- ~/.config/nvim/lua/user/plugins/my-plugins.lua
return {
    { "some/plugin", event = "VeryLazy", opts = {} },
    { "my-local-plugin", dir = "~/programming/my-plugin" },
}
```

To override an existing plugin's settings, use the same repository string - lazy.nvim deep-merges `opts` automatically:

```lua
-- ~/.config/nvim/lua/user/plugins/telescope.lua
return {
    { "nvim-telescope/telescope.nvim",
      opts = { defaults = { layout_strategy = "vertical" } },
    },
}
```

See `templates/user/plugins/example.lua` in the installed distro for more patterns.

### Overriding options, keymaps, and more

NoetherVim loads user override files after each core module. Create any of these in `~/.config/nvim/lua/user/`:

| File | What it overrides |
|---|---|
| `options.lua` | `vim.o` / `vim.g` settings |
| `keymaps.lua` | Keymaps (add, change, or remove) |
| `autocmds.lua` | Autocommands |
| `highlights.lua` | Highlight groups (runs after colorscheme) |
| `lsp/<server>.lua` | Per-server LSP settings |
| `config.lua` | Data table for bundles (vault paths, feature flags) |

Template files are provided in `templates/user/` in the installed distro - copy the ones you need and uncomment the relevant lines.

For the full override system reference, see `:help noethervim-user-config`.

---

## Bundles

Bundles are optional feature groups. Enable them in `init.lua` (see [Enabling bundles](#enabling-bundles)).

| Bundle | Contents |
|---|---|
| **Languages** | |
| `rust` | rustaceanvim - macro expansion, runnables, crate graph, hover actions |
| `go` | go.nvim - test generation, struct tags, interface impl, fill struct |
| `java` | nvim-jdtls - proper Java LSP support (jdtls requires special setup) |
| `python` | venv-selector.nvim - virtual environment switching |
| `latex` | VimTeX, noethervim-tex (snippets, textobjects, math spell dictionary) |
| `latex-zotero` | Zotero citation picker - needs Zotero |
| `web-dev` | Template-string auto-conversion + inline color preview |
| **Tools** | |
| `debug` | nvim-dap + UI (Python, Lua, JS/TS, Go adapters) |
| `test` | neotest test runner framework |
| `repl` | iron.nvim interactive REPL |
| `task-runner` | overseer.nvim task runner + compiler.nvim |
| `database` | vim-dadbod + UI + SQL completion via blink.cmp |
| `http` | kulala.nvim HTTP/REST/gRPC/GraphQL client |
| `git` | Fugitive, Flog, Fugit2 TUI, diffview, git-conflict, gitignore |
| `ai` | CodeCompanion - Anthropic, OpenAI, Gemini, Ollama, and more |
| `refactoring` | Extract function, variable, block |
| **Navigation & editing** | |
| `harpoon` | Per-project file marks (harpoon v2) |
| `flash` | Enhanced `f`/`t` and `/` motions with labels |
| `projects` | Project switcher via snacks.picker |
| `editing-extras` | Argument marking (argmark) + decorative ASCII comment boxes |
| `neoclip` | Persistent clipboard history via Telescope |
| **Writing & notes** | |
| `markdown` | render-markdown, preview, tables, math, image paste |
| `obsidian` | Obsidian vault integration (pair with markdown bundle) |
| `neorg` | `.norg` wiki and note-taking system |
| `translation` | In-editor translation via pantran.nvim (Google/Yandex) |
| **Terminal & environment** | |
| `better-term` | Named/numbered terminal windows |
| `tmux` | Automatic tmux window naming |
| `remote-dev` | Edit files on remote machines over SSH (distant.nvim) |
| **UI & appearance** | |
| `colorscheme` | 10 popular themes, persistence, highlight tweaks |
| `eye-candy` | Animations (drop.nvim, cellular-automaton), scrollbar, block display |
| `minimap` | Sidebar minimap with git/diagnostic markers |
| `helpview` | Rendered `:help` pages |
| **Practice & utilities** | |
| `training` | Vim motion and typing practice (vim-be-good, speedtyper, typr) |
| `dev-tools` | Startup profiling (`:StartupTime`), Lua scratchpad (`:Luapad`) |
| `presentation` | Slide presentations (presenting.nvim) + keypress display (showkeys) |
| `hardtime` | Motion habit trainer |

---

## Keybinding Philosophy

| Prefix | Purpose |
|---|---|
| `<Space>` (configurable) | Fuzzy navigation and search — set `vim.g.mapsearchleader` to change |
| `<Leader>` (`\`) | Global actions (format, open tools) |
| `<LocalLeader>` (`,`) | Filetype-specific actions (compile LaTeX, run script) |
| `<C-w>` | All window navigation and manipulation |
| `[` / `]` | Previous / next (diagnostics, hunks, buffers, …) |
| `[o` / `]o` | Toggle options on / off (wrap, spell, …) |

`q` closes non-editing windows (help, quickfix, Oil, notify, man, …) - this is a core distro convention.

**Discovering keymaps:** press any prefix key and wait for which-key to show available actions. Use SearchLeader+fk (default: `<Space>fk`) to search all keymaps by description, or run `:NoetherVim diff keymaps` to see what you've changed.


> [!NOTE]
> If muscle memory makes you type `:NeotherVim`, that works too.
---

## Structure

**Distro config** (installed by lazy.nvim to `~/.local/share/nvim/lazy/NoetherVim/`):

```
init.lua.example            ← starter template (copy to ~/.config/nvim/init.lua)
lua/
├── noethervim/
│   ├── init.lua            ← noethervim.setup() - runs after all plugins load
│   ├── plugins/            ← core plugin specs (always loaded)
│   ├── bundles/            ← optional feature bundles
│   ├── lsp/                ← per-server LSP configurations
│   ├── util/               ← shared utilities and icons
│   └── …                   ← options, keymaps, autocmds, …
│   └── sources/            ← custom blink.cmp completion sources
```

**Your config** (`~/.config/nvim/`):

```
init.lua                    ← lazy.setup() entry - enable bundles here
lua/
└── user/
    ├── plugins/            ← your personal plugins and opts overrides
    ├── options.lua         ← vim.o overrides
    ├── keymaps.lua         ← keymap overrides and additions
    ├── autocmds.lua        ← autocommand additions
    ├── highlights.lua      ← highlight overrides (after colorscheme)
    ├── lsp/                ← per-server LSP overrides
    └── config.lua          ← data table for bundles
```

---

## Health Check

```
:checkhealth noethervim
```

Reports on required and optional dependencies.

---

## Documentation

For the full reference - configuration system, keymap namespaces, commands,
bundle details, and FAQ - run inside Neovim:

```
:help noethervim
```

Browse NoetherVim source with `:NoetherVim files`, bundles with `:NoetherVim bundles`, and installed plugins with `:NoetherVim plugins`. When viewing a source file, run `:NoetherVim override` (or SearchLeader+ce) to open the corresponding user override file in a split - the file is created if it doesn't exist.
