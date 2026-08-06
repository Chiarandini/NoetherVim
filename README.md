# NoetherVim

A Neovim distribution with a minimal abstraction layer, named after [Emmy Noether](https://en.wikipedia.org/wiki/Emmy_Noether) (the name also contains *nvim* - *noether**Vim***).

![Dashboard, file picker, a LaTeX buffer, the which-key prefix panel, the keymap diff, and the label picker](docs/assets/hero.gif)

Latex gets the same level of support as LSP and treesitter. Everything else you'd expect is configured out of the box: completion (blink.cmp), DAP, diagnostics, formatters, etc. Startup is fast by using lazy-loading.

The distro is opinionated, but anything and everything can be overridden through `lua/user/`; in fact the distro's architecture prioritizes easy overriding (see [configuration](#configuration))


> [!NOTE]
> NoetherVim is in **alpha**. The core is stable for daily use, but what counts as a "default" vs. an "overridable" option is still being refined. These choices grew out of my Neovim use and represent my best idea of good, agnostic defaults. If you think there are better choices, [open an issue](https://github.com/Chiarandini/NoetherVim/issues) and we can address it there.
>
> **Breaking changes during alpha do not ship with deprecation shims.** Renames, command consolidations, and option-key changes land directly; the changelog and commit messages call them out. Deprecation notices (`vim.deprecate`) and a SemVer compatibility window begin at the first non-alpha release.


## Why another distribution?

There are many stable and mature Neovim distribution currently available: [LazyVim](https://www.lazyvim.org/),
[AstroNvim](https://docs.astronvim.com/), [NvChad](https://nvchad.com/), and
[LunarVim](https://www.lunarvim.org/) are all actively maintained, and
[kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) is the standard
launch-pad. **If you want distribution without strong
preferences about keymaps or workflows and follows most of the same philosophy of Noethervim,
LazyVim is probably the right pick.** It shares the same "use Neovim primitives, no DSL" principle
and has the biggest community.

NoetherVim exists for the cases where I wanted a different set of opinions:

- **Keybindings follow Vim's native prefix conventions + one addition.** `<C-w>` for window
manipulation, `[`/`]` for directional navigation, `[o`/`]o` for option toggles,
`g` for goto / LSP actions. `<Leader>` and `<LocalLeader>` stay separated
(global vs. filetype-specific, per `:help maplocalleader`). If you have
Vim-flavoured muscle memory, this feels native. There is an additional prefix native to this
distribution: a `<searchleader>` which defaults to `<Space>`, see [Keybinding
Philosophy](#keybinding-philosophy)

- **Inspection is built in.** `:NoetherVim diff keymaps` shows every distro
keymap your config has overridden; `:NoetherVim diff options` does the same
for options. "What does this distro actually change?" should be a one-command
question, even after you layer your own config on top.

- **LaTeX, BibTeX, and VimTeX are first-class,** The
distro ships custom Snacks-based label and heading pickers, preamble snippets,
and BibTeX/Zotero citation tooling, and auto-adds 1000+ mathematical terms and names to the
dictionary. See the [onboarding guide for
mathematicians](docs/onboarding/mathematicians.md).

- **Bundles cover non-coding workflows.** Bundles integrate most common other uses of neovim, for example
  `writing/` (obsidian, neorg, markdown), `practice/` (training, hardtime, presentation), and
  `terminal/` (tmux, remote-dev) are first-class categories alongside `languages/` and `tools/`.

Neovim 0.12 ships a built-in package manager (`vim.pack`), but NoetherVim
stays on lazy.nvim because the override model (deep-merged `opts`,
auto-imported bundle directories, lazy-loading via `event`/`keys`/`cmd`/`ft`)
depends on its spec system; `vim.pack` is a plain installer and doesn't
provide that layer (yet).

I also have a personal reason to build this distro; after using vim/nvim for ~10 years, my nvim
dotfiles have grown to be ~10k lines of code, so this is partly a fun project to convert my personal
setup into a distribution.

## Requirements

- Neovim >= 0.12
- A [Nerd Font](https://www.nerdfonts.com/) for icons along with a compatible terminal.
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

<br>
Some bundles need tools you install yourself. Optional extras are left out
here; `:checkhealth noethervim` reports the full picture for the bundles you
actually enabled, and every bundle file lists its own requirements in its
header.

<details>
<summary>Bundles: extra tooling</summary>

<!-- BEGIN GENERATED: bundle-requirements -->
- `go` needs Go toolchain
- `java` needs A JDK
- `latex` needs latexmk
- `latex-zotero` needs Zotero, SQLite
- `python` needs Python 3
- `rust` needs rust-analyzer, Cargo
- `web-dev` needs Node.js
- `remote-dev` needs distant, distant on the remote host
- `tmux` needs tmux
- `ai` needs curl
- `debug` needs Python 3
- `git` needs libgit2
- `http` needs curl
- `octo` needs GitHub CLI
- `repl` needs a REPL for your language
- `task-runner` needs your project build tool
- `obsidian` needs a vault path
<!-- END GENERATED: bundle-requirements -->
</details>

## Installation

Copy the starter config and open Neovim:

```bash
mkdir -p ~/.config/nvim
curl -fLo ~/.config/nvim/init.lua https://raw.githubusercontent.com/Chiarandini/NoetherVim/main/init.lua.example
nvim
```
This copies NoetherVim's `init.lua` template, which auto-installs lazy.nvim + NoetherVim and the core
plugins, and has all bundles commented out. On first launch, lazy.nvim bootstraps itself, pulls all
plugins, and runs `noethervim.setup()`. If you know what you're doing you can write the `init.lua`
file yourself - this documentation will assume you used the init.lua template provided by
NoetherVim.


> [!IMPORTANT]
> If you have an existing Neovim config, back it up first before running the above command:
> ```bash
> mv ~/.config/nvim ~/.config/nvim.bak
> mv ~/.local/share/nvim ~/.local/share/nvim.bak
> mv ~/.local/state/nvim ~/.local/state/nvim.bak
> mv ~/.cache/nvim ~/.cache/nvim.bak
> ```
> see [migrating from an existing config](#migrating-from-an-existing-config) for granular
> migration options.

> [!TIP]
> **Want to try NoetherVim without replacing your config?** Neovim's `NVIM_APPNAME` feature lets you run multiple configs side by side:
> ```bash
> mkdir -p ~/.config/noethervim
> curl -fLo ~/.config/noethervim/init.lua \
>   https://raw.githubusercontent.com/Chiarandini/NoetherVim/main/init.lua.example
> NVIM_APPNAME=noethervim nvim
> ```
> Your existing `~/.config/nvim/` stays untouched. Add `alias nv='NVIM_APPNAME=noethervim nvim'` (where `nv` can be replaced by any name you want) to your shell profile for convenience.

> [!TIP]
> **Just installed it?** [Your first session](docs/onboarding/README.md) covers the
> keybinding prefixes, the commands worth running first, and a tour of the
> defaults you can change.
>
> **Coming in primarily for LaTeX work?** Continue with the
> [onboarding guide for mathematicians](docs/onboarding/mathematicians.md): the math
> bundles, snippets, citations, and how to extend the setup.

### Updating

Run `:Lazy update` inside Neovim. This updates the distro and all plugins.

### Migrating from an existing config

Once you're running, you can bring over your personal settings:
- **Plugins**: add lazy.nvim specs to `lua/user/plugins/` (see [Configuration](#configuration))
- **Options/keymaps/autocmds**: check what the distro defaults to before re-adding (type
  `:NoetherVim diff {keymaps/options}` to check out the distro's keymaps)
- **LSP configs**: NoetherVim configures servers through `lua/noethervim/lsp/`; if you had custom server settings, look there first

### Uninstalling

Quick crash course: the following are important files/locations for any Neovim setup

| Path | Contents |
|---|---|
| `~/.config/nvim/init.lua` | Neovim's entry point that bootstraps your personal config |
| `~/.config/nvim/lua/user/` | Your plugin specs, option/keymap/autocmd overrides |
| `~/.config/nvim/lazy-lock.json` | Your pinned plugin versions |
| `~/.local/state/nvim/` | Shada (command/search history, marks, registers), undo history, sessions, views |
| `~/.local/share/nvim/site/spell/` | Custom spell additions |

Everything else under `~/.local/share/nvim/` and `~/.cache/nvim/` is installed or generated by the distro and can be regenerated by relaunching Neovim.

**To reset the distribution and keep personal data, run**
```bash
rm -rf ~/.local/share/nvim ~/.cache/nvim
```
This wipes installed plugins (lazy.nvim, NoetherVim, everything else), Mason-managed LSP servers and formatters, and all caches. Your `init.lua`, `lua/user/`, and editing state (history, undo, sessions) stay intact. Next launch re-bootstraps and reinstalls everything from scratch.


**To reset the distribution and editing state**
```bash
rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
```
Same as above but also drops shada, undo history, sessions, and views. Config is still preserved.


**To fully uninstall**
```bash
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
```
Removes the config, data, state, and cache directories. Restore your backup if you made one.


> [!TIP]
> If you installed with `NVIM_APPNAME=noethervim`, substitute `noethervim` for `nvim` in every path above.



## Configuration

### Enabling bundles

Open `~/.config/nvim/init.lua` and uncomment the bundles you want in the `spec` table. Each import path is `noethervim.bundles.<category>.<name>`:

```lua
-- inside require("lazy").setup({ spec = { ... } })
{ import = "noethervim.bundles.languages.latex" },
{ import = "noethervim.bundles.tools.debug" },
{ import = "noethervim.bundles.tools.git" },
```

All bundles are opt-in - the core is fully functional with none enabled. See [Bundles](#bundles) for the full list.

> [!TIP]
> Don't want to edit `init.lua` by hand? Open `:NoetherVim bundles` (or SearchLeader+cb), highlight a bundle, and press `<C-y>` to enable or `<C-x>` to disable. A diff prompt shows the exact change before anything is written.

### Adding your own plugins

Drop plugin specs in `~/.config/nvim/lua/user/plugins/`. Any `.lua` file there is auto-imported by lazy.nvim. To override an existing plugin's settings, use the same repository string - lazy.nvim deep-merges `opts` automatically:

```lua
-- ~/.config/nvim/lua/user/plugins/snacks.lua
return {
    { "folke/snacks.nvim",
      opts = { picker = { layout = { preset = "vertical" } } },
    },
}
```

For array-valued opts (`ensure_installed`, `formatters_by_ft`, etc.), the function-form `opts`, and adding extra `keys`/`cmd`/`event` triggers, see `:help noethervim-user-plugins`.

Plugins deliberately left out of the distribution (AI completion, translation, AI code actions, lighter jump motions) have copy-paste specs and the reasoning behind each omission in [`docs/user-config-examples.md`](docs/user-config-examples.md). For scaffolding your own files, run `:NoetherVim templates` inside Neovim.

### Overriding options, keymaps, and more

NoetherVim loads user override files after each core module. Create any of these in `~/.config/nvim/lua/user/`:

| File | What it overrides |
|---|---|
| `options.lua` | `vim.o` / `vim.g` settings |
| `keymaps.lua` | Keymaps (add, change, or remove) |
| `autocmds.lua` | Autocommands |
| `highlights.lua` | Highlight groups (runs after colorscheme) |
| `lsp/<server>.lua` | Per-server LSP settings |
| `config.lua` | Config data table: vault paths, feature flags, filetype lists (`:help noethervim-user-config-data`) |

Template files are provided in `templates/user/` in the installed distro - copy the ones you want and uncomment the relevant lines. The fastest way to grab one is `:NoetherVim templates` (or SearchLeader+ct): pick a template and press `<C-y>` to stamp it into `lua/user/`, with a diff prompt before any file is written.

For the full override system reference, see `:help noethervim-user-config`.

---

## Bundles

Bundles are optional feature groups, enabled in `init.lua` (see [Enabling bundles](#enabling-bundles)). The core is fully functional with none enabled. Full descriptions and per-bundle requirements live in [the bundle reference](https://nathanaelsrawley.com/noethervim/guides/bundles/).

<!-- BEGIN GENERATED: bundle-table -->
| Category | Bundles |
|---|---|
| Programming languages | [`go`](https://nathanaelsrawley.com/noethervim/guides/bundles/#go), [`java`](https://nathanaelsrawley.com/noethervim/guides/bundles/#java), [`latex`](https://nathanaelsrawley.com/noethervim/guides/bundles/#latex), [`latex-zotero`](https://nathanaelsrawley.com/noethervim/guides/bundles/#latex-zotero), [`python`](https://nathanaelsrawley.com/noethervim/guides/bundles/#python), [`rust`](https://nathanaelsrawley.com/noethervim/guides/bundles/#rust), [`web-dev`](https://nathanaelsrawley.com/noethervim/guides/bundles/#web-dev) |
| Tools | [`ai`](https://nathanaelsrawley.com/noethervim/guides/bundles/#ai), [`database`](https://nathanaelsrawley.com/noethervim/guides/bundles/#database), [`debug`](https://nathanaelsrawley.com/noethervim/guides/bundles/#debug), [`git`](https://nathanaelsrawley.com/noethervim/guides/bundles/#git), [`http`](https://nathanaelsrawley.com/noethervim/guides/bundles/#http), [`nvim-dev`](https://nathanaelsrawley.com/noethervim/guides/bundles/#nvim-dev), [`octo`](https://nathanaelsrawley.com/noethervim/guides/bundles/#octo), [`refactoring`](https://nathanaelsrawley.com/noethervim/guides/bundles/#refactoring), [`repl`](https://nathanaelsrawley.com/noethervim/guides/bundles/#repl), [`task-runner`](https://nathanaelsrawley.com/noethervim/guides/bundles/#task-runner), [`test`](https://nathanaelsrawley.com/noethervim/guides/bundles/#test) |
| Navigation & editing | [`editing-extras`](https://nathanaelsrawley.com/noethervim/guides/bundles/#editing-extras), [`flash`](https://nathanaelsrawley.com/noethervim/guides/bundles/#flash), [`harpoon`](https://nathanaelsrawley.com/noethervim/guides/bundles/#harpoon), [`projects`](https://nathanaelsrawley.com/noethervim/guides/bundles/#projects), [`yanky`](https://nathanaelsrawley.com/noethervim/guides/bundles/#yanky) |
| Writing & notes | [`markdown`](https://nathanaelsrawley.com/noethervim/guides/bundles/#markdown), [`neorg`](https://nathanaelsrawley.com/noethervim/guides/bundles/#neorg), [`obsidian`](https://nathanaelsrawley.com/noethervim/guides/bundles/#obsidian), [`wrapsearch`](https://nathanaelsrawley.com/noethervim/guides/bundles/#wrapsearch) |
| Terminal & environment | [`better-term`](https://nathanaelsrawley.com/noethervim/guides/bundles/#better-term), [`remote-dev`](https://nathanaelsrawley.com/noethervim/guides/bundles/#remote-dev), [`tmux`](https://nathanaelsrawley.com/noethervim/guides/bundles/#tmux) |
| UI & appearance | [`colorscheme`](https://nathanaelsrawley.com/noethervim/guides/bundles/#colorscheme), [`eye-candy`](https://nathanaelsrawley.com/noethervim/guides/bundles/#eye-candy), [`helpview`](https://nathanaelsrawley.com/noethervim/guides/bundles/#helpview), [`minimap`](https://nathanaelsrawley.com/noethervim/guides/bundles/#minimap), [`tableaux`](https://nathanaelsrawley.com/noethervim/guides/bundles/#tableaux) |
| Practice & utilities | [`hardtime`](https://nathanaelsrawley.com/noethervim/guides/bundles/#hardtime), [`presentation`](https://nathanaelsrawley.com/noethervim/guides/bundles/#presentation), [`training`](https://nathanaelsrawley.com/noethervim/guides/bundles/#training) |
<!-- END GENERATED: bundle-table -->

---

## Keybinding Philosophy

| Prefix | Purpose |
|---|---|
| `<Space>` (configurable) | Fuzzy navigation and search; set `vim.g.mapsearchleader` to change |
| `<Leader>` (`\`) | Global actions (format, open tools) |
| `<LocalLeader>` (`,`) | Filetype-specific actions (compile LaTeX, run script) |
| `<C-w>` | All window navigation and manipulation |
| `[` / `]` | Previous / next (diagnostics, hunks, buffers, …) |
| `[o` / `]o` | Toggle options on / off (wrap, spell, …) |

`q` closes non-editing windows (help, quickfix, notify, man, …)

**Discovering distro keymaps:** press any prefix key and wait for which-key to show available actions. Use SearchLeader+ck (default: `<Space>ck`) or run `:NoetherVim diff keymaps` to search all keymaps in the distribution and your user files by description and to see which keymaps were over-written. Keymaps contributed by a bundle are labelled with the bundle's name, which is searchable: typing `latex` narrows the list to the latex bundle. To search for all active keymappings (including neovim defaults and those introduced by plugins), use SearchLeader+fk (default: `<Space>fk`).

![Searching every distro keymap by description](docs/assets/diff-keymaps.gif)


---

## Structure

**Distro config** (installed by lazy.nvim to `~/.local/share/nvim/lazy/NoetherVim/`):

```
init.lua.example            ← starter template (copy to ~/.config/nvim/init.lua)
lua/
├── noethervim/
│   ├── init.lua            ← noethervim.setup() - runs after all plugins load
│   ├── plugins/            ← core plugin specs (always loaded)
│   ├── bundles/            ← optional feature bundles, grouped by category
│   │   ├── languages/      ← rust, go, java, python, latex, …
│   │   ├── tools/          ← debug, test, git, ai, database, …
│   │   ├── navigation/     ← harpoon, flash, projects, …
│   │   ├── writing/        ← markdown, obsidian, neorg, wrapsearch
│   │   ├── terminal/       ← better-term, tmux, remote-dev
│   │   ├── ui/             ← colorscheme, eye-candy, minimap, tableaux, …
│   │   └── practice/       ← training, presentation, hardtime
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
    └── config.lua          ← data table (vault paths, filetype lists, flags)
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

Browse NoetherVim source with `:NoetherVim files`, bundles with `:NoetherVim bundles`, and installed plugins with `:NoetherVim plugins`. When viewing a source file, run `:NoetherVim override` (or `<Leader>e`) to open the corresponding user override file in a split - the file is created if it doesn't exist.

> [!NOTE]
> If muscle memory makes you type `:NeotherVim`, that works too.
