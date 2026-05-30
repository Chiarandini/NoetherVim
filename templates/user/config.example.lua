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
--
-- The `---@type` annotation below tells lua-language-server (via
-- lazydev.nvim, which ships with the distro) what the returned table
-- accepts.  With it in place, the completion popup shows per-field docs
-- when you type a key, hover (`K`) shows the type + description, and
-- typos like `toggle_feedbck` get flagged by the LSP.

---@type noethervim.UserConfig
return {

    -- ── Colorscheme ───────────────────────────────────────────────────────────
    -- Default colorscheme name, applied during setup() unless the colorscheme
    -- bundle has persisted a user pick from a prior session.
    -- colorscheme = "gruvbox",

    -- If true, restore the last picked colorscheme on startup.
    -- Has no effect unless the colorscheme bundle is enabled.
    -- colorscheme_persistence = false,


    -- ── Statusline ────────────────────────────────────────────────────────────
    -- Hard opt-out for NoetherVim's built-in statusline / tabline / winbar.
    -- Set to false if you want to install lualine, mini.statusline, etc.
    -- via lua/user/plugins/.  Default: true (heirline ships out of the box).
    -- statusline_enabled = false,
    --
    -- Heirline-based statusline overrides.  Ignored when
    -- statusline_enabled = false.
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

    -- Tab key philosophy.  Three built-in styles -- "snippet" is the default.
    -- completion_style = "supertab",
    --
    -- ┌───────────────────────────┬───────────────┬───────────────────┬───────────────┐
    -- │ Scenario                  │ snippet       │ supertab          │ navigate      │
    -- ├───────────────────────────┼───────────────┼───────────────────┼───────────────┤
    -- │ Menu: select next         │ C-n           │ C-n               │ Tab / C-n     │
    -- │ Menu: select prev         │ C-p           │ C-p               │ S-Tab / C-p   │
    -- │ Menu: accept selection    │ C-y           │ Tab (also adds    │ C-y or <CR>   │
    -- │                           │               │  trailing space)  │               │
    -- │ Menu: cancel / hide       │ C-e or <Esc>  │ C-e or <Esc>      │ C-e or <Esc>  │
    -- │ Snippet: expand at cursor │ Tab           │ Tab (always wins  │ Tab (after    │
    -- │                           │               │  over menu)       │  menu nav)    │
    -- │ Snippet: jump fwd         │ Tab           │ Tab               │ Tab           │
    -- │ Snippet: jump back        │ S-Tab         │ S-Tab             │ S-Tab         │
    -- │ Snippet: cancel jumps     │ <Esc>         │ <Esc>             │ <Esc>         │
    -- │ Cmdline: next match       │ Tab (selects  │ Tab               │ Tab           │
    -- │                           │  + inserts)   │                   │               │
    -- │ Cmdline: prev match       │ S-Tab         │ S-Tab             │ S-Tab         │
    -- └───────────────────────────┴───────────────┴───────────────────┴───────────────┘
    --
    -- Notes on each style:
    --   "snippet"   Tab is reserved for LuaSnip; menu nav is C-n/C-p, accept is
    --               C-y.  Snippet expansion and menu navigation never fight.
    --               Pick this if you live in snippets and prefer muscle memory
    --               that matches plain vim's "completion is C-n / C-y".
    --   "supertab"  Tab does the obvious thing in IDE muscle memory: snippets
    --               win when expandable, otherwise accept the menu item with
    --               trailing space.  Best for users coming from VSCode.
    --   "navigate"  Tab cycles the menu (= C-n) without accepting -- the classic
    --               nvim-cmp default.  Best for users migrating from older
    --               cmp setups.
    --
    -- AI completion (Copilot / Codeium / supermaven / smart-actions) is NOT
    -- bundled.  When you add one, bind its accept-word action to Tab inside
    -- lua/user/keymaps.lua AFTER blink loads; it will shadow whatever the
    -- chosen style does for Tab.  Minimal sketch:
    --
    --     vim.keymap.set("i", "<Tab>", function()
    --       if require("copilot.suggestion").is_visible() then
    --         require("copilot.suggestion").accept_word()
    --       else
    --         -- fall through to blink / luasnip
    --         vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "n", false)
    --       end
    --     end, { desc = "ai accept / completion" })
    --
    -- Bracket insertion after accept is owned by blink (completion.accept.auto_brackets,
    -- already on); the standalone autopair plugin (mini.pairs in noethervim.plugins.autopair)
    -- handles bracket pairing while you type and is configured separately.
    --
    -- To remap individual completion keys (C-y, C-n/C-p, C-Space, etc.) drop a
    -- spec into lua/user/plugins/ that overrides blink.cmp's `opts.keymap`.
    -- See :help noethervim-completion-custom for ready-to-copy snippets.

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


    -- ── Toggle feedback ───────────────────────────────────────────────────────
    -- Channel for the confirmation message shown when a bracket-prefix toggle
    -- (`[ow`, `]os`, etc.) fires.
    --   "notify" (default) -- vim.notify, rendered as a snacks toast
    --   "echo"             -- nvim_echo, classic one-line cmdline message
    --                         (still kept in `:messages`)
    --   "off"              -- silent
    -- toggle_feedback = "echo",

}
