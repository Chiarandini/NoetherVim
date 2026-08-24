# User config examples

Copy-paste snippets for plugins NoetherVim declined to ship, and for
behaviours it deliberately left off a plugin it does ship. Drop each file
under `~/.config/nvim/lua/user/plugins/` and restart Neovim.

Every entry names a reason the distribution made the choice it did, so you
can judge whether that reasoning applies to you. That is the bar for being
here at all: if the honest answer were "the distribution could ship this and
just has not", the fix would be a bundle, and documenting the workaround
would only make it permanent. Something you have to write yourself because
the distro made no choice for you belongs in a bundle, not on this page.

The entries that override rather than add say so, and say what they cost:
a default the distribution defends is not the same as a default nobody
thought about.

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

## Fuzzy `/` inside Oil

Replaces `/` in Oil buffers with a fuzzy picker over the entries currently
listed, rather than an in-buffer search. Non-recursive, so it is the
narrow counterpart to the distro's `gf`, which recurses through
`Snacks.picker.files`.

This one is an override, and that is why the distribution does not ship
it. An Oil buffer is an ordinary Neovim buffer, which is the whole premise
of the plugin: `dd` deletes a file because it deletes a line, and `/`
searches the listing because it searches any buffer. Every keymap
NoetherVim adds to Oil sits behind `g` or `y` for that reason, extending
the buffer rather than reinterpreting it. Rebinding `/` trades a motion
you already know for a picker, and it is a fair trade to make for
yourself; it is not one to make on someone else's behalf.

Inside the picker, `<CR>` does what `<CR>` on the entry does in Oil (enter
a directory, open a file) and `<S-CR>` lands the Oil cursor on the entry
without opening it, so you can act on it with the usual Oil keys.
`<S-CR>` needs a terminal that distinguishes it from `<CR>` (the kitty
keyboard protocol) — the same requirement as the `browse` picker.

The picker itself ships with the distribution -- `gt` in the latex bundle is
the same one, narrowed to `.tex` files -- so the override is a keymap and a
call:

```lua
-- ~/.config/nvim/lua/user/plugins/oil-fuzzy.lua
vim.api.nvim_create_autocmd("FileType", {
    pattern = "oil",
    callback = function(args)
        vim.keymap.set("n", "/", function()
            require("noethervim.util.oil_pick").pick()
        end, {
            buffer = args.buf,
            desc = "fuzzy-find entries in this dir",
        })
    end,
})
```

`pick()` takes an optional table:

- `filter` -- `fun(entry): boolean`, to list only the entries it accepts
- `title` -- picker title; the Oil directory when omitted
- `empty` -- what to say when nothing matches
- `auto_select` -- with exactly one match, act on it and skip the picker
- `keys` -- `{ jump = "<S-CR>" }`, to move the jump key elsewhere

A `.tex`-only variant, for instance, passes
`filter = function(entry) return entry.name:match("%.tex$") ~= nil end`.

Bind it to a free key instead of `/` if you want the picker without giving
up search. `g/` is free in Oil buffers: neither oil.nvim nor the distro
binds it there, and the `wrapsearch` bundle's `g/` only acts in writing
filetypes. Taken already are `g?`, `g.`, `g\`, `g~`, `gd`, `gf`, `gG`,
`gs`, `gS`, `gV`, `gx`, `gX`, `gz` and `gZ`, plus `gt` and `gP` with the
latex bundle on.

## Mode colour in the number column

Repeats the statusline's insert-mode signal in the number column, by
recolouring `CursorLineNr` when the mode changes. Two indicators for one
piece of state, at opposite corners of the screen, so it is in view
wherever you are looking.

Not shipped, for one concrete reason: `CursorLineNr` belongs to the
colorscheme, and repainting it on every `ModeChanged` puts the distribution
in a fight with any theme or plugin that also sets it. The statusline is
NoetherVim's to paint; the number column is not. As a personal choice on a
theme you have already settled, that objection does not apply.

```lua
-- ~/.config/nvim/lua/user/autocmds.lua
local ns = vim.api.nvim_create_augroup("user_mode_linenr", { clear = true })

-- Read the colours off the statusline palette so this tracks the theme,
-- and the mode colours you may already have overridden in config.lua.
local function mode_fg()
    local ctx = require("noethervim.plugins.statusline.context")
    return ctx.mode_colors[vim.fn.mode(1):sub(1, 1)] or ctx.colors.text_gray
end

local base
vim.api.nvim_create_autocmd({ "ModeChanged", "ColorScheme" }, {
    group = ns,
    callback = function()
        -- Captured once, so turning this off is a matter of deleting the
        -- augroup and re-applying the colorscheme.
        base = base or vim.api.nvim_get_hl(0, { name = "CursorLineNr" })
        vim.api.nvim_set_hl(0, "CursorLineNr",
            vim.tbl_extend("force", base, { fg = mode_fg(), bold = true }))
    end,
})
```

For the whole column rather than the cursor line, use `LineNr` instead --
louder, and worth trying before deciding which you want.
