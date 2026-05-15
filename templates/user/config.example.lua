-- noethervim-template-version: 1
-- Personal configuration for NoetherVim.
-- The fastest way to install this template is `:NoetherVim templates` (or
-- SearchLeader+ct, default <Space>ct): pick `user/config.example.lua` and
-- press <C-y> to stamp it into lua/user/config.lua.  You can also copy
-- it manually if you prefer.
-- lua/user/config.lua is gitignored - it never ships with the distribution.
--
-- This is the single user-facing configuration surface.  Any key left
-- nil (or absent) falls back to the distro default.

return {

    -- ── Colorscheme ───────────────────────────────────────────────────────────
    -- Default colorscheme name, applied during setup() unless the colorscheme
    -- bundle has persisted a user pick from a prior session.
    -- colorscheme = "gruvbox",

    -- If true, restore the last picked colorscheme on startup.
    -- Has no effect unless the colorscheme bundle is enabled.
    -- colorscheme_persistence = false,


    -- ── Statusline ────────────────────────────────────────────────────────────
    -- Heirline-based statusline overrides.
    -- statusline = {
    --     -- Shape of the colored mode block at the left of the statusline
    --     -- (and, for "slant"/"pointy"/"bubbly", an opening endcap on the
    --     -- right ruler block).  Default "round" preserves the historical
    --     -- look; "bubbly" rounds both edges; "straight" disables endcaps.
    --     edge_style = "round",  -- "round" | "slant" | "pointy" | "straight" | "bubbly"
    --
    --     -- Override heirline color-table entries.  Keys match heirline's
    --     -- color names (mode_n, mode_i, git_added, ...).
    --     colors = { mode_n = "#458588" },
    --
    --     -- Extra heirline component specs appended to the right side of
    --     -- the main statusline, after the git block.
    --     extra_right = {},
    --
    --     -- Glyph shown on a tabpage that contains an unsaved buffer.
    --     -- Default " ●".  Common alternatives: " [+]" (vim default),
    --     -- " *", " ", " ◉".
    --     tab_modified_indicator = " ●",
    -- },


    -- ── Obsidian ──────────────────────────────────────────────────────────────
    -- Path to your Obsidian vault.  Used by the `obsidian` bundle.
    -- obsidian_vault = "~/Documents/MyVault/",


    -- ── Blink completion ──────────────────────────────────────────────────────
    -- Filetypes where keyword-triggered completion is suppressed (conservative mode).
    -- C-Space and LSP trigger chars (e.g. '\' in LaTeX) still work normally.
    -- blink_conservative_filetypes = { "tex", "latex" },

    -- Files larger than this (in KB) also get conservative mode, regardless of filetype.
    -- blink_conservative_size_kb = 500,

    -- Tab key philosophy.  Choices:
    --   "snippet"   (default) Tab is reserved for LuaSnip jumps.  Pick from the
    --               completion menu with C-n/C-p, accept with C-y.  Snippet expansion
    --               and menu navigation never fight over the same key.
    --   "supertab"  When the menu is visible, Tab accepts the highlighted item and
    --               inserts a trailing space.  When no menu is open, Tab falls
    --               back to a snippet jump (then to literal Tab).  S-Tab still
    --               jumps backwards through snippets.
    --   "navigate"  Tab cycles forward through the menu (= C-n) without accepting,
    --               like the classic nvim-cmp default and most VSCode setups.
    --               C-y or <CR> commits.  S-Tab cycles backward.
    -- completion_style = "supertab",
    --
    -- The two philosophies people actually fight about are "supertab" (IDE-style
    -- muscle memory) and "snippet" (vim-vsnip / LuaSnip purist) -- those are
    -- ~99% of setups.  "navigate" is here for users coming from older nvim-cmp
    -- configs.  AI completion (Copilot/Codeium/etc.) is a fourth axis: bind Tab
    -- to the AI plugin's accept_word in lua/user/keymaps.lua to shadow this.
    --
    -- Bracket insertion after accept is owned by blink (completion.accept.auto_brackets,
    -- already on); the standalone autopair plugin (mini.pairs in noethervim.plugins.autopair)
    -- handles bracket pairing while you type and is configured separately.

    -- ── Animations ────────────────────────────────────────────────────────────
    -- Set drop = false to disable seasonal drop.nvim animations (default: enabled).
    -- drop = false,

    -- ── Filetype profiles ─────────────────────────────────────────────────────
    -- Extra filetypes to treat as writing (wrap, linebreak, spell, conceallevel=2,
    -- formatoptions+t).  Defaults: tex, markdown, norg, text, gitcommit, gitsendemail,
    -- mail, rst, typst.
    -- writing_filetypes = { "vimwiki", "quarto" },

    -- Extra filetypes that skip BOTH the writing and code profiles -- their own
    -- ftplugin / buffer settings take over (e.g. listchars stay off).  Defaults
    -- include json, yaml, toml, help, qf, oil, terminal, dashboard, dap-ui, etc.
    -- non_code_filetypes = { "csv" },

    -- Enable spellcheck in code buffers.  Scoped to comments and strings via
    -- treesitter @spell captures (identifiers are NOT spellchecked).  `[os` /
    -- `]os` still toggle per-buffer; `zg` adds a word to your spellfile.
    -- For CamelCase-heavy languages, you can additionally set
    --   vim.opt.spelloptions:append("camel")
    -- in lua/user/options.lua so getUserName is split as get/User/Name.
    -- Default: false.
    -- spell_in_code = true,

}
