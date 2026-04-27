-- Personal configuration for NoetherVim.
-- Copy this file to lua/user/config.lua and fill in your values.
-- lua/user/config.lua is gitignored - it never ships with the distribution.
--
-- Any key left nil (or absent) falls back to the distro default.

return {

    -- ── Obsidian ──────────────────────────────────────────────────────────────
    -- Path to your Obsidian vault.  Used by the `obsidian` bundle.
    -- obsidian_vault = "~/Documents/MyVault/",


    -- ── Blink completion ──────────────────────────────────────────────────────
    -- Filetypes where keyword-triggered completion is suppressed (conservative mode).
    -- C-Space and LSP trigger chars (e.g. '\' in LaTeX) still work normally.
    -- blink_conservative_filetypes = { "tex", "latex" },

    -- Files larger than this (in KB) also get conservative mode, regardless of filetype.
    -- blink_conservative_size_kb = 500,

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

}
