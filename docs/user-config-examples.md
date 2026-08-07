# User config examples

Copy-paste snippets for plugins NoetherVim declined to ship. Drop each file
under `~/.config/nvim/lua/user/plugins/` and restart Neovim.

Every entry names a reason the distribution will not ship the plugin, so you
can judge whether that reasoning applies to you. That is the bar for being
here at all: if the honest answer were "the distribution could ship this and
just has not", the fix would be a bundle, and documenting the workaround
would only make it permanent. Something you have to write yourself because
the distro made no choice for you belongs in a bundle, not on this page.

For how `opts` merging works when you adapt these, see
`templates/user/plugins/example.lua` or `:help noethervim-user-plugins`.

## Translation (pantran.nvim)

In-editor translation popup via Google Translate or Yandex. Binds
`<C-w><m-t>` and `:Pantran`. Not shipped as a bundle: the integration is
one plugin with one keymap, and a translation window has little editing
surface for a text editor.

```lua
-- ~/.config/nvim/lua/user/plugins/pantran.lua
return {
    {
        "potamides/pantran.nvim",
        cmd  = "Pantran",
        keys = {
            { "<c-w><m-t>", "<cmd>Pantran<cr>", desc = "Translate" },
        },
        opts = {
            default_engine = "google",
            engines = {
                yandex = {
                    default_source = "auto",
                    default_target = "en",
                },
            },
            controls = {
                mappings = {
                    edit   = { n = { ["j"] = "gj", ["k"] = "gk" }, i = {} },
                    select = { n = {} },
                },
            },
        },
    },
}
```

## AI completion (Copilot)

Inline AI suggestions. Not shipped as a bundle, and not planned as one:
every option in this space needs an account, a subscription, or an API
key, so the distribution would be picking a vendor on your behalf.

The one thing worth getting right is the `<Tab>` handover. Bind it in
`lua/user/keymaps.lua` rather than in the spec, so it runs after blink
has installed whichever `completion_style` you chose and shadows it.

```lua
-- ~/.config/nvim/lua/user/plugins/copilot.lua
return {
    {
        "zbirenbaum/copilot.lua",
        event = "InsertEnter",
        opts = {
            suggestion = { enabled = true, auto_trigger = true, keymap = false },
            panel      = { enabled = false },
        },
    },
}
```

```lua
-- ~/.config/nvim/lua/user/keymaps.lua
vim.keymap.set("i", "<Tab>", function()
    local ok, suggestion = pcall(require, "copilot.suggestion")
    if ok and suggestion.is_visible() then
        suggestion.accept_word()
    else
        vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "n", false)
    end
end, { desc = "ai accept / completion" })
```

Substitute `supermaven-inc/supermaven-nvim` or `Exafunction/codeium.nvim`
for the spec; the `<Tab>` handover has the same shape in each case.

## Lightweight jump motions (nvim-jump)

A smaller alternative to the `flash` bundle: labelled jumps without
flash's search integration, remote operations, or treesitter selection.
Worth swapping in if you want the jump motion and none of the rest.

```lua
-- ~/.config/nvim/lua/user/plugins/nvim-jump.lua
return {
    {
        "yorickpeterse/nvim-jump",
        keys = {
            { "<leader>j", function() require("nvim-jump").jump() end,
              mode = { "n", "x", "o" }, desc = "labelled [j]ump" },
        },
        opts = {},
    },
}
```

Leave `noethervim.bundles.navigation.flash` commented out in `init.lua`
if you use this, so the two do not both claim `f` / `t`.

## AI code actions (smart-actions.nvim)

AI-suggested code actions on `grA`, with an inline diff preview before
anything is applied. Not a bundle, because the settings that matter are
personal ones: which model to use, whether to prefetch speculatively, how
much surrounding code to send.

```lua
-- ~/.config/nvim/lua/user/plugins/smart-actions.lua
return {
    {
        "Chiarandini/smart-actions.nvim",
        cmd  = { "SmartAction", "SmartActionCancel", "SmartActionLastDiff" },
        keys = {
            { "grA", function() require("smart_actions").run() end,
              mode = { "n", "x" }, desc = "smart code [A]ction" },
        },
        opts = {
            default_scope = "ask",
            categories    = { "quickfix" },
        },
    },
}
```

Provider resolution is automatic: the `claude` CLI on `$PATH` first
(reusing your Claude Code login), otherwise `ANTHROPIC_API_KEY` from the
environment. See `:help smart-actions` once installed.
