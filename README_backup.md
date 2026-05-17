# Dotfiles

These are a collection of my Dotfiles. I will eventually add an explanation of the
philosophy of my setup and the key shortcuts to navigate it efficiently. Currently, there
is no good way to one-click install it. It is also assumed that you are completely
familiar with \[most of\] vim/nvim and lazy (ex. options, local to buffer/window/tab,
auto-commands, ftplugins, diff modes like {x,v,s,n}, lua, nvim api, folding, lazy, lsp,
and so forth).


# Major information

Important properties:

- 'q' closes a window wherever it is "reasonable", i.e. that there is no need to record a macro
  (ex. re-naming window buffer, message window buffer, etc.)
- WhichKey is installed, and the keyboard shortcuts come labeled. It is set to a delay of
  1.5s so that there isn't an annoying pop-up that shows up every-time you hesitate.
- \<esc\> will also close any notification pop-ups and un-highlight search items.

The files for the nvim configuration is organized like thus:


nvim
- lua
  - configs  : has plugin configuration
  - plugins  : has plugin installation and all lazy info (including key-mappings and commands)
  - settings : has custom keymappings, autocommands, toggles, fault-management, etc.
  - sources  : custom cmp sources
  - utils    : any utility/helper file goes here
- luasnip   : luasnip snippets goes here (they are lua snippets, not vscode or snipmate snippets)
- preamble  : custom chunks for quickly constructing latex preambles
- session   : auto-generated to quickly "recover" current session (see alpha configuration)
- spell     : additional correctly spelled words for the spellchecker/lsp to ignore (read vim manual)

## statusline
The statusline contains lots of useful information.
- lsp: which one is active (colour coded)
- git: which branch your on, with changes
- compiling: if on TeX file, status and progress of compilation
- name of file (optional: path from project root)
- whether or not registering macro, "q\<key\>"
- size of latex document (if applicable)
- compilation status of a latex document
- debugging information (when applicable).

## keyboard shortcuts

The leader key is ''`\`''. The leader key representing doing an __action__ :
| Keymap   | \<leader\>...                  |
| -------- | -----------------------------  |
| r        | refactor                       |
| R        | Run                            |
| b        | box text                       |
| d        | debug                          |
| o        | obsidian                       |
| f        | format                         |
| h        | hunk                           |
| S        | Spotify Actions                |
| s        | camelCase/snake_case converter |
| t        | toggle a window                |



The local leader is `,`. This is reserved for extra actions in that are exposed in certain filetypes only.
Files/plugins that use local-leader are:
- norg
- latex
- iron (many programming setups have certain run configurations)
- debugging

The `[` and `]` keys are for different actions that come in pairs:

| Keymap    | prev/next...               |
|-----------|----------------------------|
| s         | miss-spelled word          |
| b         | tab                        |
| d         | diagnostic                 |
| e         | swap with prev/next line   |
| \<sapce\> | add blankline above/bellow |
| h         | toggle hunk                |
| j         | join/unjoin lines of code  |
| m         | method start               |
| \[/\]     | next "block" or "heading"  |
| M         | method end                 |
| p         | pwd in lualine             |
| t         | todo comment               |
| z         | folds                      |

There is a special toggle which is under `o` (`[o / ]o`) which mostly toggles *options*
(hence the `o`), however it may toggle other things like LSP. A toggle is usually placed
under \[o or \]o if it doesn't move anything on the screen (though it may add virtual text
or column-text for visual enhancement) or doesn't edit the file (hence, \[h/\]h doesn't
have an o in front of it, while \[oL/\]oL does)

| Keymap | `[o`=on, `]o`=off       |
|--------|-------------------------|
| s      | miss-spelled word       |
| a      | auto-chdir              |
| b      | light background        |
| B      | visualize code-blocks   |
| c      | cursorline              |
| d      | diff this               |
| h      | hlsearch                |
| I      | Illuminate plugin       |
| i      | ignore case             |
| l      | see trailing characters |
| L      | Lsp start               |
| s      | spell                   |
| S      | scrollbind              |
| T      | treesitter enable       |
| u      | cursor column           |
| v      | virtual edit            |
| w      | wrap                    |
| W      | animated window         |
| x      | x on cursor             |
| N      | center n/N              |

There are many different pop-up windows that are available to show more information or to
perform more granular actions. All pop-ups are accessible through the \<c-w\> key.

| Keymap   | \<c-w\>...                    |
| -------- | ----------------------------- |
| \<c-g\>  | Lazy Git                      |
| \<c-o\>  | oil mode                      |
| \<c-r\>  | Murren Replace                |
| \<c-s\>  | Spectre Replace               |
| \<c-t\>  | Transalte                     |
| \<c-u\>  | undo tree                     |
| \<c-m\>  | mason                         |
| \<c-l\>  | lspInfo                       |
| d        | debug ui                      |
| h        | harpoon                       |
| o        | outline                       |
| l        | Lazy plugin manager...        |
| t        | terminal toggle               |
| e        | filer explorer toggle         |


The ''navigation''/''picker'' is hidden behind the "Navigation leader key" which
is: `<space>`, and most of it is done via Telescope/snacks, however there are times when other
plugins do a better job for a specific task (ex. quickfix is dealt by Trouble):

| Keymap    | \[=on, \]=off                 |
| --------  | ----------------------------- |
| /         | fuzzy search current file     |
| \<space\> | Browse current dir            |
| C         | Colorschemes                  |
| P         | Downlaod Plugins              |
| q         | quixfix (using trouble)       |
| r         | resume last Telescope search  |
| T         | select terminal               |
| t         | table of contents (ToC)       |
| d         | diagnostics...                |
| D         | Debug...                      |
| e         | editor files...               |
| g         | grep...                       |
| l         | lsp...                        |
| w         | wiki...                       |
| f         | find...                       |
| c         | config...                     |


The \<space\>f  and \<space\>c are a  bit special. The \<sapce\>f  hides most telescope pickers that aren't mapped to
a particular key:

| Keymap | description                    |
|--------|--------------------------------|
| B      | Bookmarks                      |
| b      | buffer                         |
| c      | commands                       |
| f      | files in cwd                   |
| G      | git changes                    |
| h      | help                           |
| k      | keymaps                        |
| m      | marks                          |
| n      | notifications                  |
| o      | old files                      |
| p      | project files (looks for .git) |
| t      | todos                          |
| u      | undo                           |
| d      | documents...                   |

The `<space>fd` hides some more granular document searching. The `<space>c` has the following
options:
| Keymap | description                |
|--------|----------------------------|
| c      | nvimconfig files           |
| C      | all config files           |
| s      | settings                   |
| f      | ftplugins                  |
| p      | plugin setup (lazy config) |
| P      | Preambles                  |
| s      | snippets                   |


Other important custom keybindings are:

| Keymap    | description                    | mode |
| --------- | -------------------------------| ---- |
| \|        |  create tmp vsplit             |  n   |
| +         | tab edit                       |  n   |
| _         | tmp horizontal split           |  n   |
| J         | keep cursor same position j    |  n   |
| K         | keep cursor same position k    |  n   |
| L         | vim.lsp.hover()                |  n   |
| ;         | remaps to :                    |  n   |
| U         | remaps to \<c-r\>              |  n   |
| \<c-r\>   | remaps to U                    |  n   |
| \<c-t\>   | buffer file call-stack         |  n   |
| \<c-s\>   | show file in neotree           |  n   |
| \<c-\/\>  | comment                        |  n   |
| \<c-;\>   | open terminal                  |  n   |
| \>\>/\<\< | Move Paramaters around         |  n   |
| \<c-l\>   | auto-spelling fix              |  i   |
| \<c-=\>   | \<c-r\>=                       |  i   |
| T         | Tabluarize with key \[input\]  |  v   |
| c         | search/replace selected        |  v   |

Note that \<c-t\> replaces the default behavior of vim which jumps to previous tag. With
the advancements of LSP's, combo-ed with \<c-o\>, I found I never used \<c-t\>, and thus
have "upgraded" it to something more useful, which is a way to navigate to most recent
files opened in the current buffer.
