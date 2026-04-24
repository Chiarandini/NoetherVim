# User config examples

Copy-paste snippets for features that live outside the distribution. Drop
each file under `~/.config/nvim/lua/user/plugins/` and restart Neovim.

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
