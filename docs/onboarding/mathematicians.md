# Onboarding for mathematicians

This guide is for mathematicians who have seen Neovim from a distance -
maybe used it for LaTeX with a minimal `init.vim`, maybe watched a
colleague fly through a paper in it - and want to make the jump to a
fully-configured setup without spending a month reading help files.

This document is not a Vim tutorial and not an argument for switching editors. It is
targeting people who already want to. The goal is to shorten the path from install to
a setup where you can actually write a paper, take notes, manage references, etc.

---

## 1. Who this guide is for

You know, or can tolerate, Vim basics: modes, `hjkl`, `:w`, `:q`,
`/search`. If `hjkl` means nothing to you, start with section 2 first.

You write math (papers, notes, thesis chapters, problem sets) in
LaTeX, Typst, Markdown, or some mix of them. You want to get to a
working setup quickly and iterate from there, rather than read every
manual before opening a file.

What you will find below: concrete keymaps, a walkthrough for writing a
LaTeX paper, pointers to the deeper documentation when you need it.
What you will not find: a re-derivation of Vim motions,
a complete reference (can be found at `:help noethervim`), and the
plugin docs this guide links to.

## 2. Before you start: minimal Vim literacy

You do not need to master Vim before using NoetherVim. The distribution
is usable with surface-level knowledge and actively teaches you more
through the which-key popup (see section 4).

That said, three resources are worth keeping open the first week:

- **`:Tutor`**: run inside any Neovim install. About 30 minutes. Teaches
  modes, basic motions, `dd`/`yy`/`p`, search, and writing buffers.
  This is the single best use of your time as a new Vim user.
- **[learnvim](https://learnvim.irian.to/)**: a free book on modal
  editing intuition. Skim the first few chapters to internalize why, for example,
  `ci"` is better than selecting and retyping.
- **`:help user-manual`**: the canonical reference. Not for reading cover to cover (it
  will take ~9 hours, see [this link][https://www.youtube.com/watch?v=rT-fbLFOCy0]); look
  into when you want to understand something properly.

If you hit a specific motion or command you don't know, `:help <thing>`
almost always has an answer. Neovim's help system is one of the most reliable
piece of documentation in the entire ecosystem.

## 3. Installation

Installation lives in the main README: see
[Installation](../../README.md#installation). Two things worth
highlighting for a mathematician coming from another editor:

- **Don't wipe your existing config blindly.** If you already have
  `~/.config/nvim/`, use the `NVIM_APPNAME=noethervim` (or any other name besides
  `noethervim`) pattern from the
  README's install section. You can run NoetherVim and your old setup
  side by side with no interference.
- **Let the first launch finish.** Lazy.nvim bootstraps itself, pulls
  plugins, compiles treesitter parsers, and (if you enable the LaTeX
  bundle) installs the language server through Mason. First launch
  takes at most minute or two. Subsequent launches are fast (usually <50ms).

Once `nvim` opens without errors and the dashboard appears, you're
ready.

## 4. Orientation: your first session

When Neovim opens with no file, you land on the **Snacks dashboard** - a
NoetherVim ASCII header with a short menu:

```
New File (insert)  [i]
New File (normal)  [e]
Find File          [f]
Old Files          [o]
Restore Session    [r]
Sessions           [s]
Config             [c]
Quit               [q]
```

Press the letter in brackets. `f` opens the fuzzy file picker in your
current directory; `c` jumps to your config.

### Keybinding prefixes

NoetherVim builds on Vim's own prefix conventions rather than funneling
everything through one leader. The prefixes you will actually use:

| Prefix | Meaning |
|---|---|
| `<Space>` (SearchLeader) | Fuzzy finding: files, grep, buffers, keymaps, help |
| `<Leader>` (`\` by default) | Global actions: format, open tools |
| `<LocalLeader>` (`,` by default) | Filetype-specific: compile LaTeX, run a script |
| `<C-w>` | Anything window-related: navigate, resize, split |
| `[` / `]` | Previous / next: diagnostics, hunks, buffers, theorems |
| `[o` / `]o` | Toggle options: wrap, spell, relative numbers |

`q` closes non-editing windows (help, quickfix, Oil, notify). This is a
distribution convention - use it instead of `:q` for anything that
isn't a file buffer.

### Discovery: which-key

Press any prefix and wait for a second. A popup appears listing every
key that follows, grouped by category. If you forget "how do I jump
between hunks again?", press `[` and read. This is the habit that
replaces memorizing the manual.

### The `:NoetherVim` command

`:NoetherVim <tab>` autocompletes the subcommands. The ones worth
knowing day one:

- `:NoetherVim bundles`: picker of every bundle with enable/disable
  status. Answers "what else could I turn on?" Press `<C-y>` on a
  bundle to enable it (edits `init.lua` behind a diff prompt), or
  `<C-x>` to disable.
- `:NoetherVim templates`: picker of the bundled user-config
  templates (`options`, `keymaps`, `autocmds`, …). Press `<C-y>` to
  stamp one into `lua/user/`, with a diff prompt before any write.
- `:NoetherVim plugins`: picker of every installed plugin. Good for
  reading a plugin's source when `:help` isn't enough.
- `:NoetherVim files`: picker of NoetherVim's own source files.
- `:NoetherVim user`: picker of your `lua/user/` files.
- `:NoetherVim override`: from any NoetherVim source file, open the
  matching user override file in a split. Creates it if missing. One of the more useful command for customization.

`<Space>fk` searches all keymaps by description. `:NoetherVim diff
keymaps` (or `<space>ck`) shows what you've personally changed.

## 5. Enabling the math bundles

Open `~/.config/nvim/init.lua` (or whichever path you installed to)
and uncomment the bundles you want. Each one is a single line in the
`spec` table:

```lua
-- Core math + writing
{ import = "noethervim.bundles.languages.latex" },
{ import = "noethervim.bundles.languages.latex-zotero" },  -- needs Zotero running
{ import = "noethervim.bundles.typst" },                   -- may still be stabilizing
{ import = "noethervim.bundles.writing.markdown" },

-- Optional, depending on your note-taking habit
{ import = "noethervim.bundles.writing.obsidian" },
{ import = "noethervim.bundles.writing.neorg" },
```

Save the file, quit, and reopen Neovim. Lazy.nvim picks up the changes
and installs what's new on next launch.

After the install settles, run `:checkhealth noethervim`. It reports on
required dependencies (TeX distribution, `latexmk`, `tinymist` for
Typst, Zotero translator if you enabled zotero, `uv`/Python for image
tooling) and tells you exactly which command to run if something is
missing.

## 6. Writing a LaTeX paper

The LaTeX bundle gives you the same level of support as an IDE: live
compilation, forward/reverse PDF sync, snippet-driven math entry,
citation picker, theorem navigation, and a 900-entry math spell
dictionary.

### Compile and preview

VimTeX handles compilation. Open a `.tex` file and:

- `<LocalLeader>ll`: start continuous compilation (latexmk watches the
  file and recompiles on save).
- `<LocalLeader>lv`: open the PDF in your viewer.
- `<LocalLeader>lc`: clean auxiliary files.
- `<LocalLeader>le`: show the error/warning log if compilation fails.

Forward search (jump from `.tex` cursor to PDF location) and reverse
search (click in the PDF, jump to the source line) need a viewer set
up per OS. On macOS, [Skim](https://skim-app.sourceforge.io/) with
"Sync" enabled works out of the box. On Linux, Zathura with SyncTeX
is the common choice. VimTeX's documentation covers the setup:
`:help vimtex-synctex`.

A couple of NoetherVim-specific extras on top of VimTeX:

- `yP`: copy the compiled PDF path to the system clipboard (useful
  for drag-and-drop into email or a tracker).
- `[P` / `]P`: toggle whether the PDF size shows in the statusline.
- `<LocalLeader>vw`: run VimTeX's word count.

### Math entry via snippets

The bundle ships the `noethervim-tex` plugin, which adds hundreds of
LuaSnip snippets tuned for mathematical writing. Snippets come in two
flavors:

- **Auto-expanding** (fire the moment the trigger is typed, inside
  math mode only). Examples:
  - `ff` -> `\frac{}{}` with tab stops on numerator and denominator
  - `pp` -> `\partial`
  - `ee` -> `e^{}`
  - `((` -> `\left( \right)` pair
  - `bb` -> `\bar{}`
- **Manual** (type the trigger and press `<Tab>` to expand). Used for
  larger scaffolds so you don't get surprise expansions:
  - `:thm Title` -> full theorem environment with label
  - `:defn`, `:prop`, `:lem`, `:cor`, `:example`, `:exercise`, `:box`

A handful of text abbreviations also auto-expand: `tfae` -> "the
following are equivalent", `iff` -> "if and only if", `wrt`, `wlog`,
`ftsoc`, `SES`, `fg`. These snippets are also aware if you are in math-mode or text-mode
and will expand accordingly.

Open `:NoetherVim plugins`, pick `noethervim-tex`, and browse
`LuaSnip/tex/` for the full snippet catalog. Context detection
(math zone vs. text zone vs. tikz) means snippets only fire where
they make sense.

### Preamble

At the start of a line in the preamble (above `\begin{document}`),
type `@` and press `<Tab>` to get a picker of `.tex` files from your
preamble folder; useful if you maintain shared macros across
documents. Set the folder via `lua/user/config.lua`:

```lua
return {
    preamble_folder = "~/Documents/LaTeX/preamble/",
}
```

### Textobjects: editing by theorem

The bundle adds treesitter-powered textobjects for LaTeX structure.
These work with any operator (`d`, `y`, `c`, `v`):

- `]g` / `[g` - next / previous theorem (or any theorem-like env)
- `]p` / `[p` - next / previous proof
- `]x` / `[x` - next / previous example
- `]c` / `[c` - next / previous chapter

Combined with VimTeX's own `ie` / `ae` (inside / around environment)
and `i$` / `a$` (inline math): `dae` deletes a whole environment,
`ci$` replaces the contents of `$...$`, `vag` selects a theorem with
its surrounding delimiters.

### Spell checking that knows math

Spell is on in `.tex` files by default. Math regions are excluded
automatically so that something like `$\alpha + \beta$` will not flag. The distribution
ships a custom dictionary with mathematical terms (Noetherian,
cohomology, homomorphism, tensor, manifold, ...) so real words don't
light up.

Add your own by pressing `zg` on a word in normal mode to add the word to your local vim
dictionary, or simply edit `~/.local/share/nvim/site/spell/en.utf-8.add` directly.

### Citations

With the `latex-zotero` bundle enabled and Zotero running, press
`<LocalLeader>z` for a picker over your Zotero library. Pick an entry
and the correctly-formatted `\cite{key}` lands at the cursor.

Without Zotero, press `<C-S-c>` in insert mode (while writing
`\cite{`) for a picker over `.bib` files in the project.

As you type `\cite{`, completion also kicks in from the current
bibliography.

### Images

Copy an image to your clipboard (screenshot, paper figure, diagram
from a colleague) and press `<LocalLeader>P`. A `figure` environment
is inserted at the cursor with a caption stub, the image saved to a
nearby directory, and the path wired up.

## 7. Writing with Typst

Typst is an alternative to LaTeX: faster compilation, cleaner syntax,
Lua-like scripting.

With the typst bundle enabled and `tinymist` + `typst` on your `$PATH`
(`brew install tinymist typst` on macOS), opening a `.typ` file gives
you:

- Live preview via markview rendering inline.
- Language server features via `tinymist`: completion, diagnostics,
  goto-definition on `@label` references.
- A parallel set of snippets for math and environments. The trigger
  conventions mirror the LaTeX bundle where it makes sense
  (`:thm`, `:defn`, `:prop`) so muscle memory transfers.

Compile output lives alongside the source. For most single-document
work the live preview is enough; for larger projects, `typst compile
file.typ` from the shell produces a PDF.

My two cents on picking LaTeX vs Typst: Picking Typst is good if you want fast incremental compilation,
you aren't locked into a LaTeX journal template, you'd rather write
`$ a^2 + b^2 = c^2 $` than `\begin{equation} a^2 + b^2 = c^2
\end{equation}`, and you're willing to live with a smaller package
ecosystem (though this is a shrinking concern as Typst matures).

## 8. Notes, references, and research workflow

 NoetherVim gives
you three paths; pick the one that matches how you already think.

**Plain Markdown + `markdown` bundle.** The lightest option.
Render-markdown.nvim concealed formatting in-buffer (headings, bold,
lists), mdmath.nvim renders `$...$` math inline, and markdown-preview
gives you a browser preview on `:MarkdownPreview`. Paste images the
same way as LaTeX: `<LocalLeader>P`. Good if you keep notes as
individual files in a `notes/` directory.

**Obsidian vault + `obsidian` bundle.** If you already use Obsidian
for notes, this bundle makes NoetherVim a first-class editor for your
vault. Set your vault path in `lua/user/config.lua`:

```lua
return { obsidian_vault = "~/Documents/MyVault/" }
```

Then `<Leader>ol` follows the link under the cursor, `<C-s>` in
insert mode opens the quick switcher, and the picker surfaces
`<C-n>` (new note), `<C-l>` (insert link), `<C-x>` (tag) shortcuts.
Your Obsidian app and NoetherVim edit the same files.

**Neorg + `neorg` bundle.** A structured `.norg` wiki format, good
for thesis-style hierarchical notes or long-running research journals.
Default workspace is `~/neorg/`. Key openers:

- `<Space>ww` - open the wiki index.
- `<Space>wt` / `<Space>wv` - index in a new tab / vertical split.
- `<LocalLeader>nc` - table of contents for the current norg file.

Neorg has a steeper learning curve than Markdown but pays off if you
want outlined, exportable, linked notes as a system rather than a
folder of files.

## 9. Extending NoetherVim

You will eventually want to change something: a keymap, a color, a
plugin option. NoetherVim's override system is designed so you never
fork the distribution or edit its files.

Your personal configuration lives in `~/.config/nvim/lua/user/`:

| File | What you put there |
|---|---|
| `options.lua` | `vim.o.textwidth = 120`, `vim.o.tabstop = 2`, and so on |
| `keymaps.lua` | New keymaps or reassignments of distro ones |
| `autocmds.lua` | Autocommands (`BufWritePre`, `FileType`, etc.) |
| `highlights.lua` | `vim.api.nvim_set_hl(...)` calls, run after colorscheme |
| `plugins/*.lua` | New plugin specs or `opts` overrides on distro plugins |
| `lsp/<server>.lua` | Per-server LSP settings |
| `config.lua` | Data table: vault paths, preamble folder, feature flags |

For a concrete example, to change the compile key to use `<LocalLeader>c`:

```lua
-- ~/.config/nvim/lua/user/keymaps.lua
vim.keymap.set("n", "<LocalLeader>c", "<Plug>(vimtex-compile)",
    { desc = "Compile (custom)" })
```

From any core NoetherVim file opened via `:NoetherVim files`, press
`<Space>ce` (the same keymap as `:NoetherVim override`) to open the
matching user override file in a split. NoetherVim creates it if it
doesn't exist and puts you at the right place.

For the full override system (loading order, how `opts` tables merge,
how to disable a plugin from a bundle) see `:help
noethervim-user-config`.

## 10. When things break

Four commands, in order, will diagnose almost any problems:

1. **`:checkhealth noethervim`** - reports on every dependency and
   configuration requirement. Run this first. The output tells you
   which external tool is missing or mis-configured.
2. **`:Lazy`** - shows plugin state: installed, loaded, failed. Press
   `L` (inside the Lazy UI) for recent install/update log output.
3. **`:Mason`** - shows LSP server, formatter, and linter state. If
   LaTeX lint stops working, a reinstall from here fixes it 90% of
   the time.
4. **`:messages`** - anything that scrolled past during startup. Error
   messages often appear here and nowhere else.

If all four come back clean but something is still off, open an issue:
<https://github.com/Chiarandini/NoetherVim/issues>. Include
`:checkhealth noethervim` output and the specific file / keymap / bundle
that's misbehaving.

## 11. Going deeper

You do not have to read any of the following to use NoetherVim well. These are further
documentation to improve your knowledge of Neovim:

- **`:help user-manual`** - the Vim user manual, rendered inside your
  editor. The single most reliable reference for modal editing.
- **[Neovim Lua guide](https://neovim.io/doc/user/lua-guide.html)** -
  when you want to write your own autocommand, override, or plugin
  spec. Short and well-paced.
- **[VimTeX documentation](https://github.com/lervag/vimtex)** - the
  LaTeX workflow has far more depth than this guide covers (custom
  compilers, remote compilation, inverse search tuning,
  language-specific features).
- **[Typst documentation](https://typst.app/docs/)** - Typst as a
  language is still evolving; official docs are the source of truth.
- **[lazy.nvim spec reference](https://lazy.folke.io/spec)** - read
  before writing a plugin override so your `keys` / `event` / `ft` /
  `opts` table actually behaves the way you expect.
- **Castel, ["How I'm able to take notes in mathematics lectures using
  LaTeX and Vim"](https://castel.dev/post/lecture-notes-1/)** - the
  post that introduced a generation of mathematicians to snippet-based
  real-time LaTeX. Most of the ideas behind the NoetherVim LaTeX
  bundle trace back here.
