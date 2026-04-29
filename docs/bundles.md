# Bundles

Bundles are optional feature groups. Enable them by uncommenting `{ import = "noethervim.bundles.<category>.<name>" }` lines in `~/.config/nvim/init.lua`. The core works with none enabled.

Some bundles have external dependencies:
- `latex` needs `latexmk` and a TeX distribution
- `debug` needs Python 3 with `debugpy` for Python debugging
- `ai` needs an API key (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc.)

## Programming languages

| Bundle | Contents |
|---|---|
| `rust` | rustaceanvim - macro expansion, runnables, crate graph, hover actions |
| `go` | go.nvim - test generation, struct tags, interface impl, fill struct |
| `java` | nvim-jdtls - proper Java LSP support (jdtls requires special setup) |
| `python` | venv-selector.nvim - virtual environment switching |
| `latex` | VimTeX, noethervim-tex (snippets, textobjects, math spell dictionary) |
| `latex-zotero` | Zotero citation picker - needs Zotero |
| `web-dev` | Template-string auto-conversion + inline color preview |

## Tools

| Bundle | Contents |
|---|---|
| `debug` | nvim-dap + UI (Python, Lua, JS/TS, Go adapters) |
| `test` | neotest test runner framework |
| `repl` | iron.nvim interactive REPL |
| `task-runner` | overseer.nvim task runner + compiler.nvim |
| `database` | vim-dadbod + UI + SQL completion via blink.cmp |
| `http` | kulala.nvim HTTP/REST/gRPC/GraphQL client |
| `git` | Fugitive, Flog, Fugit2 TUI, diffview, git-conflict, gitignore |
| `ai` | CodeCompanion - Anthropic, OpenAI, Gemini, Ollama, and more |
| `smart-actions` | AI-suggested code actions on `grA` (Claude Code / Anthropic) |
| `refactoring` | Extract function, variable, block |
| `octo` | GitHub PRs / issues / reviews via `gh` CLI (`<C-w>O` for PR list) |
| `nvim-dev` | Neovim config development: `:StartupTime`, `:Luapad`, vimls LSP for `.vim` files |

## Navigation & editing

| Bundle | Contents |
|---|---|
| `harpoon` | Per-project file marks (harpoon v2) |
| `flash` | Enhanced `f`/`t` and `/` motions with labels |
| `projects` | Project switcher |
| `editing-extras` | Argument marking (argmark) + decorative ASCII comment boxes |
| `yanky` | Yank ring -- cycle through paste history with `<C-p>`/`<C-n>` after a paste |

## Writing & notes

| Bundle | Contents |
|---|---|
| `markdown` | render-markdown, preview, tables, math, image paste |
| `obsidian` | Obsidian vault integration (pair with markdown bundle) |
| `neorg` | `.norg` wiki and note-taking system |

## Terminal & environment

| Bundle | Contents |
|---|---|
| `better-term` | Named/numbered terminal windows |
| `tmux` | Automatic tmux window naming |
| `remote-dev` | Edit files on remote machines over SSH (distant.nvim) |

## UI & appearance

| Bundle | Contents |
|---|---|
| `colorscheme` | 10 popular themes, persistence, highlight tweaks |
| `eye-candy` | Animations (drop.nvim, cellular-automaton), scrollbar, block display |
| `minimap` | Sidebar minimap with git/diagnostic markers |
| `helpview` | Rendered `:help` pages |
| `tableaux` | noethervim-tableaux -- animated mathematical dashboard scenes |

## Practice & utilities

| Bundle | Contents |
|---|---|
| `training` | Vim motion and typing practice (vim-be-good, speedtyper, typr) |
| `presentation` | Slide presentations (presenting.nvim) + keypress display (showkeys) |
| `hardtime` | Motion habit trainer |
