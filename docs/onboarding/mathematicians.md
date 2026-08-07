# Onboarding for mathematicians

This guide is for mathematicians who have minimally used Neovim
(ex. used it for LaTeX with a minimal `init.vim`) and want to make the jump to a
fully-configured setup without spending too much time reading help files.

This document is not a Vim tutorial and not an argument for switching editors. It is
targeting people who already want to. The goal is to shorten the path from install to
a setup where you can actually write a paper, take notes, manage references, etc.

It builds on [your first session](first-session.md), which covers everything
not specific to mathematics: minimal Vim literacy, the keybinding prefixes,
the commands worth running first, and the defaults you can change. Do that one
first; this guide assumes it.

---

## 1. Who this guide is for

You know, or can tolerate, Vim basics: modes, `hjkl`, `:w`, `:q`, `/search`.
If `hjkl` means nothing to you, start with the Vim literacy section of
[your first session](first-session.md).

You write math (papers, notes, thesis chapters, problem sets) in
LaTeX, Markdown, or some mix of them. You want to get to a
working setup quickly and iterate from there.

What you will find below: concrete keymaps, a walkthrough for writing a
LaTeX paper, pointers to the deeper documentation when you need it.
What you will not find: a re-derivation of Vim motions,
a complete reference (can be found at `:help noethervim`), and the
plugin docs this guide links to.

One thing worth knowing before the first launch: lazy.nvim bootstraps itself,
pulls plugins, compiles treesitter parsers, and installs the LaTeX language
server through Mason once you enable the bundle below. The first launch takes
at most a minute, usually no more than 5 seconds, and subsequent ones are
usually under 50ms.

## 2. Enabling the math bundles

Open `~/.config/nvim/init.lua` (or whichever path you installed to)
and uncomment the bundles you want. Each one is a single line in the
`spec` table:

```lua
-- Core math + writing
{ import = "noethervim.bundles.languages.latex" },
{ import = "noethervim.bundles.writing.zotero" },  -- needs Zotero running
{ import = "noethervim.bundles.writing.markdown" },

-- Optional, depending on your note-taking habit
{ import = "noethervim.bundles.writing.obsidian" },
{ import = "noethervim.bundles.writing.neorg" },
```

Save the file, quit, and reopen Neovim. Lazy.nvim picks up the changes
and installs what's new on next launch.

After the install settles, run `:checkhealth noethervim`. It reports on
required dependencies (TeX distribution, `latexmk`, Zotero translator if
you enabled zotero, `uv`/Python for image tooling) and tells you exactly
which command to run if something is missing.

## 3. Writing a LaTeX paper

The LaTeX bundle gives you the same level of support as an IDE: live
compilation, forward/reverse PDF sync, snippet-driven math entry,
citation picker, theorem navigation, and a 1000+ math spell
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
- `<C-w>sp`: toggle whether the PDF size shows in the statusline.
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
documents. The folder defaults to `preamble/` inside your config
directory. Point it elsewhere with an `opts` override on the
`NoetherVim-Tex` spec:

```lua
-- ~/.config/nvim/lua/user/plugins/noethervim-tex.lua
return {
    { "Chiarandini/NoetherVim-Tex",
      opts = { preamble_folder = "~/Documents/LaTeX/preamble/" },
    },
}
```

### Motions: navigating by theorem

The bundle adds treesitter-powered normal-mode motions for LaTeX
structure, in the `[` / `]` pairing the rest of the distribution uses:

- `]g` / `[g` - next / previous theorem (or any theorem-like env)
- `]p` / `[p` - next / previous proof, `]P` / `[P` for its `\end`
- `]x` / `[x` - next / previous example, `]X` / `[X` for its `\end`
- `]c` / `[c` - next / previous chapter

These are motions, not textobjects, and they compose with operators the way
`]m` or `]}` do: `d]g` deletes from the cursor to the start of the next
theorem, `v]g` extends a selection there, `y]g` yanks the span.

To operate on a whole environment rather than the span between two, use
VimTeX's textobjects: `ie` / `ae` (inside / around environment) and `i$` /
`a$` (inline math). `dae` deletes a whole environment and `ci$` replaces the
contents of `$...$`.

### Spell checking that knows math

Spell is on in `.tex` files by default. Math regions are excluded
automatically so that something like `$akdjfh$` will not flag. The distribution
ships a custom dictionary with mathematical terms (Noetherian,
cohomology, homomorphism, tensor, manifold, ...) so real words don't
light up.

Accented words are handled too, which stock spell checking gets wrong.
Neovim sees `Poincar\'e` as the letters that are literally there and flags it,
because the accent is a TeX escape rather than a character. The bundle decodes
those escapes first and spell-checks the word they spell, so `Poincar\'e` is
checked as *Poincaré* and passes. Misspellings inside an accented word are
still caught, and are reported as diagnostics as well as highlights.

Add your own words by pressing `zg` on one in normal mode. In `.tex` buffers
`zg` is routed: an accented word goes to the accent dictionary in its decoded
form, a plain one to your ordinary spell file. You can also edit
`~/.local/share/nvim/site/spell/en.utf-8.add` directly.

The `:NoetherTexAccent*` commands cover the rest: `Add`, `MarkWrong`,
`Suggest` for corrections, `Diagnostic` to control whether accent findings
appear in the diagnostic list, and `AccentSpell` to toggle the feature per
buffer.

### Citations

With the `zotero` bundle enabled and Zotero running, press
`<LocalLeader>z` for a picker over your Zotero library. Pick an entry
and the correctly-formatted `\cite{key}` lands at the cursor.

Without Zotero, press `<C-S-c>` in insert mode (while writing
`\cite{`) for a picker over `.bib` files in the project.

As you type `\cite{`, completion also kicks in from the current
bibliography.

### Images

Copy an image to your clipboard (screenshot, paper figure, diagram from a
colleague) and press `<LocalLeader>P`. You are prompted for a file name,
defaulting to a timestamp, and a complete `figure` environment is inserted at
the cursor with the caption left for you to fill in.

The image is written as a `.png` into an `images/` directory beside the
document, created if it is not there. The `\includegraphics` path is relative
to that document rather than absolute.

Dragging an image onto the window does the same thing. In Markdown buffers the
same key inserts `![caption](path)` instead.

## 4. Notes, references, and research workflow

To organize your non-latex notes, NoetherVim gives you three
paths as bundles.

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

- `<Leader>ww` - open the wiki index.
- `<Leader>wt` / `<Leader>wv` - index in a new tab / vertical split.
- `<LocalLeader>nc` - table of contents for the current norg file.

Neorg has a steeper learning curve than Markdown but pays off if you
want outlined, exportable, linked notes as a system rather than a
folder of files.

## 5. Tuning the LaTeX setup

The general override system is covered by
[your first session](first-session.md) and `:help noethervim-user-config`.
What follows is the handful of places specific to
workflows covered in this document:

**Change a VimTeX keymap.** The compile key, for instance:

```lua
-- ~/.config/nvim/lua/user/keymaps.lua
vim.keymap.set("n", "<LocalLeader>c", "<Plug>(vimtex-compile)",
    { desc = "Compile (custom)" })
```

**Point the preamble picker somewhere else,** if you keep shared macros
outside your config directory:

```lua
-- ~/.config/nvim/lua/user/plugins/noethervim-tex.lua
return {
    { "Chiarandini/NoetherVim-Tex",
      opts = { preamble_folder = "~/Documents/LaTeX/preamble/" },
    },
}
```

**Change where pasted figures land,** or the environment they are wrapped in,
by overriding img-clip's `tex` filetype entry in
`~/.config/nvim/lua/user/plugins/`.

**Add your own snippets.** LuaSnip files in `LuaSnip/tex/` inside your config
directory are picked up alongside the bundle's. This is the usual way to grow
a personal notation set.

To find the file behind any of these, open `:NoetherVim bundles`, select
`latex`, and press `<C-o>`. That seeds an override file listing every plugin
the bundle declares, so you can uncomment the one you want to change.

## 6. When things break

Four commands, in order, diagnose almost anything:

1. **`:checkhealth noethervim`** reports on every dependency and
   configuration requirement. Run this first; the output names the external
   tool that is missing or mis-configured.
2. **`:Lazy`** shows plugin state: installed, loaded, failed. Press `L` inside
   the Lazy UI for recent install and update logs.
3. **`:Mason`** shows LSP server, formatter and linter state. If LaTeX
   linting stops working, reinstalling from here usually fixes it.
4. **`:messages`** holds anything that scrolled past during startup. Errors
   often appear there and nowhere else.

If all four come back clean and something is still off, open an issue at
<https://github.com/Chiarandini/NoetherVim/issues> with the
`:checkhealth noethervim` output and the specific file, keymap or bundle that
is misbehaving.

## 7. Going deeper on LaTeX

None of this is required. It is where to look once the setup above stops being
the limiting factor:

- **`:help vimtex`** and the
  [VimTeX documentation](https://github.com/lervag/vimtex) cover far more than
  this guide: custom compilers, remote compilation, inverse-search tuning,
  multi-file projects, and the full textobject set.
- **`:help noethervim-tex`** documents the snippet engine, the accent
  spell-checker, and the treesitter motions in detail, including how to write
  context-aware snippets of your own.
- **`:help luasnip`**, specifically the section on `condition` and dynamic
  nodes, is what you need before writing snippets that fire only in math mode.
- **VimTeX's textobjects** (`ie`/`ae` for environments, `i$`/`a$` for inline
  math, `id`/`ad` for delimiters) compose with every operator, and repay
  learning more than any single keymap in this guide.
- **Castel, ["How I'm able to take notes in mathematics lectures using LaTeX
  and Vim"](https://castel.dev/post/lecture-notes-1/)** is the post that
  introduced a generation of mathematicians to snippet-based real-time LaTeX.
  Most of the ideas behind the NoetherVim LaTeX bundle trace back to it.
