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

```lua
-- ~/.config/nvim/lua/user/plugins/oil-fuzzy.lua
local function fuzzy_pick_in_oil()
    local oil    = require("oil")
    local Snacks = require("snacks")
    local bufnr  = vim.api.nvim_get_current_buf()
    local win    = vim.api.nvim_get_current_win()

    -- Read entries off the buffer lines so the picker mirrors exactly what
    -- Oil is showing: no recursion, and the hidden-files toggle is honoured
    -- for free.
    local items = {}
    for lnum = 1, vim.api.nvim_buf_line_count(bufnr) do
        local entry = oil.get_entry_on_line(bufnr, lnum)
        if entry and entry.name ~= ".." then
            table.insert(items, {
                text = entry.name,
                lnum = lnum,
                dir  = entry.type == "directory",
            })
        end
    end
    if #items == 0 then return end

    -- Move the Oil cursor onto `item`, then optionally run `after` there.
    -- Deferred so it fires once the picker has fully torn down.
    local function land_on(item, after)
        vim.schedule(function()
            if not (item and vim.api.nvim_win_is_valid(win)) then return end
            vim.api.nvim_set_current_win(win)
            vim.api.nvim_win_set_cursor(win, { item.lnum, 0 })
            if after then after() end
        end)
    end

    local dir = oil.get_current_dir(bufnr)
    Snacks.picker({
        title  = dir and vim.fn.fnamemodify(dir, ":~") or "Oil",
        layout = "select",
        -- Return focus to the Oil window rather than snacks' default "main",
        -- which excludes floats. For a floating Oil, restoring focus to the
        -- window behind it fires oil's own WinLeave auto-close and the float
        -- is gone before the deferred select() can run.
        main   = { current = true },
        items  = items,
        format = function(item)
            local icon, hl = Snacks.util.icon(item.text, item.dir and "directory" or "file")
            return {
                { icon .. " ", hl },
                { item.text, item.dir and "SnacksPickerDirectory" or "SnacksPickerFile" },
            }
        end,
        confirm = function(picker, item)
            picker:close()
            land_on(item, oil.select)
        end,
        actions = {
            jump_to_entry = function(picker)
                local item = picker:current()
                picker:close()
                land_on(item)
            end,
        },
        win = {
            input = {
                keys = {
                    ["<S-CR>"] = { "jump_to_entry", mode = { "i", "n" },
                                   desc = "jump to entry (no open)" },
                },
            },
        },
    })
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "oil",
    callback = function(args)
        vim.keymap.set("n", "/", fuzzy_pick_in_oil, {
            buffer = args.buf,
            desc = "fuzzy-find entries in this dir",
        })
    end,
})

return {}
```

Bind it to a free key instead of `/` if you want the picker without giving
up search. `g/` is free in Oil buffers: neither oil.nvim nor the distro
binds it there, and the `wrapsearch` bundle's `g/` only acts in writing
filetypes. Taken already are `g?`, `g.`, `g\`, `g~`, `gd`, `gf`, `gG`,
`gs`, `gS`, `gV`, `gx`, `gX`, `gz` and `gZ`.

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
