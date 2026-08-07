# Your first session

This walkthrough assumes NoetherVim is installed and Neovim is open. It is
about twenty minutes long and ends with a configuration file of your own, one
bundle enabled, and a clean health check. Each step is explicit about what
keys to press, what commands to type, and what you should see.

If you are here primarily for LaTeX, do this page first for the general
layout, then continue with
[onboarding for mathematicians](mathematicians.md).

---

## Before you start: minimal Vim literacy

You do not need to master Vim first. Surface-level knowledge is enough to
edit, and the which-key panel in step 2 names the keys as you go. Configuring
the distribution is a second skill, and no panel covers it. Steps 5 and 6
write configuration out from templates instead; [what this did not teach
you](#what-this-did-not-teach-you) lists what that path skips.

If modes, `hjkl` and `:w` mean nothing to you yet, four resources are worth
keeping open the first week:

- **`:Tutor`** runs inside any Neovim install. About thirty minutes, covering
  modes, motions, `dd`/`yy`/`p`, search, and writing buffers. This is the
  single best use of your time as a new Vim user.
- **[vimtutor-sequel](https://github.com/micahkepe/vimtutor-sequel)** numbers
  its lessons 8 through 16, picking up where `:Tutor` ends: splits,
  spellcheck, advanced search and replace, macros, sessions and registers,
  change navigation. It ships as a text file and a launcher script, run
  outside Neovim: install the Homebrew formula, or clone the repo and open a
  copy of the text file with the vimrc beside it. Lessons 13 and 14 cover
  Vimscript and Vundle-era plugin managers.
- **[learnvim](https://learnvim.irian.to/)** is a free book on modal-editing
  intuition. Skim the first few chapters to internalise why `ci"` beats
  selecting and retyping.
- **`:help user-manual`** is the canonical reference. Not for reading cover to
  cover; open it when you want to understand something properly.

If you hit a command you do not know, `:help <thing>` almost always has an
answer. Neovim's help system is one of the most reliable pieces of
documentation in the ecosystem.

A Noethervim bundle covers the drilling: `practice.training` adds three games, each behind its own
command. For our purposes, the game that matters is `:VimBeGood` which gamifies going over vim for
motions. Furthermore, `practice.hardtime` warns on, or blocks, repeated `hjkl` and other low-value
motions. Step 6 enables either one.

## 1. Open a file

Run `nvim` with no arguments. You get a dashboard: an ASCII header and a short
menu, each entry marked with the key that runs it.

Press `f`. A fuzzy file picker opens on the current directory. Type part of a
filename, press `<CR>`, and you land in a normal buffer.

That buffer already has more going on than stock Neovim. If the file is in a
language with a server available, the LSP, completion, treesitter, formatting
and diagnostics attach on their own; if the server or parser is not installed
yet, which is normal on a fresh install, it is installed for you.

### Prose files and code files behave differently

Open a `.md` or `.tex` file and the editor changes shape. Lines soft-wrap at
the window edge, with `↳` marking each continuation row so a wrapped line is
never mistaken for a new one. Spellcheck is on, and `<C-l>` in insert mode
fixes the last misspelling. Typing past column 100 breaks the line for you.

Open a `.lua` or `.py` file and none of that happens. Lines run off the right
edge rather than wrapping, `›` marks where one continues past the edge, tabs
and trailing spaces are drawn, and nothing reflows as you type, because in
code a line break is syntax rather than presentation.

This is one setting, chosen by filetype, and it is worth knowing early for
two reasons. It is the thing most likely to make NoetherVim look broken to
someone arriving from another config, since prose behaving differently from
code is not standard Neovim. And it means a tutorial that says "turn on
`wrap`" has already been answered for you in one kind of file and
deliberately not in the other.

Some filetypes are in neither camp: JSON, YAML, help pages, Oil, terminals.
They keep whatever their own plugins set.

`:help noethervim-filetype-profiles` lists exactly what each one sets, and
`[ow` / `]ow` turn wrapping on and off for the window whenever you disagree.

## 2. Discovering keybindings: press a prefix and wait
Press `<Space>` and stop. After a moment a which-key panel lists everything
available under it. Press `f` and the panel narrows to the file pickers. Press
`<Esc>` to back out.

Now try the same with `<Leader>` (`\` by default), with `[`, and with `<C-w>`.

Each prefix owns one kind of action, and that is the point of the scheme:
instead of remembering individual keys, you remember which prefix owns the
thing you want and read the panel. `<Space>` searches for something,
`<Leader>` acts on the editor, `[` and `]` move backwards and forwards through
lists, `<C-w>` manipulates windows. The full table is in [keybinding
philosophy](../../README.md#keybinding-philosophy), but the habit of pausing
after a prefix will teach you more of it than reading the table would.

## 3. See every keymap at once

Press `<Space>?`.

A buffer opens listing every active keymap, grouped by namespace. It reads
live state, so it already reflects your install. Press `<CR>` on any line to
jump to the file where that keymap was defined.

Search it for something you expect to exist, then close it with `q`.

That covers what NoetherVim binds. To search every active mapping, including
Neovim's own and those added by plugins, press `<Space>fk`.

## 4. Move around the filesystem with Oil

Press `<C-w><C-o>`. A floating window opens showing the current directory as
an editable buffer. This is [oil.nvim](https://github.com/stevearc/oil.nvim),
configured out of the box.

- `<CR>` on a directory enters it, `-` goes to the parent, `<CR>` on a file
  opens it.
- The listing is a normal buffer. Rename a file by editing its line, delete
  one with `dd`, create one by adding a line. Nothing touches disk until you
  `:w`, and a confirmation lists every change first.
- `g?` shows every Oil keymap, including the extras NoetherVim adds: `yp`
  yanks the full path, and there are pickers to find and grep inside the
  directory you are looking at.

`q` closes the float. Oil is worth two minutes now because it replaces both a
file tree and a trip to the shell for most day-to-day file work.

## 5. Create your configuration file

Press `<Space>ct`, highlight `user/config.example.lua`, and press `<C-y>`.

A diff appears showing exactly what will be written. Press `y` or `<CR>` to
accept it. The new `lua/user/config.lua` opens, with every key commented out,
so it changes nothing yet.

Read it top to bottom. It is the complete list of what NoetherVim lets you
change about its own behaviour: colorscheme, statusline shape, the Tab-key
philosophy for completion, which filetypes count as writing, what a bare `q`
closes. Uncomment anything you disagree with.

The file is typed. With the `---@type noethervim.UserConfig` line at the top,
`<C-Space>` inside the table completes key names and shows documentation for
each, and typos get flagged.

Your `init.lua` is a separate file, and it is where the next step writes.
`<Leader>i` opens it from anywhere. That is bound to Neovim's own
`:e $MYVIMRC`, so the plain command works too.

## 6. Enable a bundle

NoetherVim starts with no bundles enabled. The core is complete on its own,
and bundles are opt-in groups for workflows you choose to add: LaTeX,
debugging, a git UI, Obsidian notes.

Press `<Space>cb` for the catalogue. Each row shows a bundle, what it
provides, and whether it is already active.

Pick one you want and press `<C-y>`. A diff shows the exact line being added
to your `init.lua` before anything is written. Accept it, then restart Neovim
so lazy.nvim installs it.

If nothing obvious appeals, `tools.git` is a good first one. `<C-x>` disables
a bundle the same way, and `<C-o>` seeds a file for overriding one, once you
want to change how a bundle is configured.

## 7. Confirm the install is healthy

Run `:checkhealth noethervim`.

It reports your Neovim version, terminal capabilities, the tools each enabled
bundle needs, which of your override files loaded, and whether any of them has
fallen behind the file it overrides. Warnings here are worth reading now
rather than meeting later as a bug.

## 8. Find the rest of the commands

Run `:NoetherVim` with no arguments. It prints every subcommand with a
one-line description, and `<Tab>` after `:NoetherVim ` completes them.

You have already used three behind their keymaps: `templates` (`<Space>ct`),
`bundles` (`<Space>cb`) and `keymap-guide` (`<Space>?`). The rest browse the
distribution's own source, list installed plugins, report which of your
override files loaded, and compare your configuration against the defaults.

---

## What you have now

A `lua/user/config.lua` you can edit, one bundle enabled, and a way to answer
four questions without leaving the editor: *what is bound* (`<Space>?`), *what
can I turn on* (`<Space>cb`), *what else can this do* (`:NoetherVim`), and *is
anything wrong* (`:checkhealth noethervim`).

## What this did not teach you

Steps 5 and 6 wrote configuration out from templates, through a diff. That path
ends at the first change the distribution made no decision about. Past it sit
four things, all of them Neovim's and lazy.nvim's, none specific to this
distribution:

- **Lua, enough to read and write a table.** The [Neovim Lua
  guide](https://neovim.io/doc/user/lua-guide.html) is short, and the
  prerequisite for the other three.
- **The lazy.nvim plugin spec.** `keys`, `cmd`, `ft` and `event` control when
  a plugin loads. `opts` merges into a spec that already exists; `config`
  replaces it. An override that silently does nothing is usually that
  distinction. The [spec reference](https://lazy.folke.io/spec) is the
  authority. `:help noethervim-user-plugins` covers the cases specific to
  overriding a plugin the distribution already configures: array-valued opts,
  the function form, adding a trigger without dropping the existing ones.
- **`vim.keymap.set`.** Every line of `lua/user/keymaps.lua` is a call to it.
  `:help vim.keymap.set` is one screen.
- **Autocommands and their events.** `:help events` lists the moments
  behaviour can attach to. `lua/user/autocmds.lua` is where it goes.

## If a step did not work

- Run `:checkhealth noethervim` first. Most first-launch problems are a
  missing external tool, and it names them.
- To tell whether a problem is yours or the distribution's, start with
  `NOETHERVIM_NO_USER=1 nvim`, which skips every file in `lua/user/`.
- `:Lazy` shows plugin status and load times. A bundle enabled in step 6 that
  never installed will be visible there.
- `:messages` holds anything that scrolled past during startup. Errors often
  appear there and nowhere else.

## Where to go next

- `:help noethervim` is the reference manual, and the authoritative source for
  everything summarised here. It is also
  [published on the web](https://nathanaelsrawley.com/noethervim/reference/) if
  you want to link someone to a section.
- [Notable keybindings](../notable-keybindings.md) argues for the individual
  bindings that displaced a Vim default, and gives the snippet for each. Read
  it if a default here surprised you and you want to know what it bought.
- `:NoetherVim diff keymaps`, `diff options` and `diff autocmds` show what you
  have changed relative to the defaults. This is the fastest way to check
  whether an override took effect.
- Your configuration lives in `~/.config/nvim/lua/user/`. `<Space>ct` writes a
  starting template for each file, and `:help noethervim-user-config` explains
  how the layering works.
