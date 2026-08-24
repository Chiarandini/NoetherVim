--- Fuzzy picker over the entries of the current Oil buffer.
---
--- Two flows, and a key each. Either you want the entry opened, or you want
--- to be *on* it so you can act with the usual Oil keys (rename, yank, zip).
--- `<CR>` serves the first -- it does exactly what pressing `<CR>` on the
--- entry in Oil does, directory or file -- and `<S-CR>` the second: it lands
--- the Oil cursor on the entry and stops there. That is the shape `<S-CR>`
--- carries elsewhere in the distro (see ftplugin/qf.lua): the plain key acts,
--- the shifted one is the variant that stops short of acting.
---
--- Items are read off the buffer lines rather than the filesystem, so the
--- list mirrors exactly what Oil is showing -- non-recursive, and honouring
--- the hidden-files toggle. Callers narrow it with `filter`.
---
--- `<S-CR>` needs a terminal that distinguishes it from `<CR>` (kitty
--- keyboard protocol -- `:checkhealth noethervim` reports whether yours does).

local M = {}

local DEFAULT_KEYS = { jump = "<S-CR>" }

---@class noethervim.oil_pick.Opts
---@field filter? fun(entry: table): boolean  keep only entries this returns true for
---@field title? string                       picker title (default: the Oil directory)
---@field empty? string                       notify text when nothing matches
---@field auto_select? boolean                skip the picker when exactly one entry matches
---@field keys? { jump?: string }             rebind the jump key

---@param opts? noethervim.oil_pick.Opts
function M.pick(opts)
  opts = opts or {}
  local keys   = vim.tbl_extend("force", DEFAULT_KEYS, opts.keys or {})
  local oil    = require("oil")
  local Snacks = require("snacks")
  local bufnr  = vim.api.nvim_get_current_buf()
  local win    = vim.api.nvim_get_current_win()

  local items = {}
  for lnum = 1, vim.api.nvim_buf_line_count(bufnr) do
    local entry = oil.get_entry_on_line(bufnr, lnum)
    if entry and entry.name ~= ".." and (not opts.filter or opts.filter(entry)) then
      items[#items + 1] = {
        text = entry.name,
        lnum = lnum,
        dir  = entry.type == "directory",
      }
    end
  end
  if #items == 0 then
    vim.notify(opts.empty or "[oil] no entries to search", vim.log.levels.WARN)
    return
  end

  -- Land the Oil cursor on `item` (refocus the Oil window + move the cursor),
  -- then optionally run `after` in that window. Deferred so it fires after the
  -- picker has fully torn down. Shared by <CR> (open) and <S-CR> (jump).
  local function land_on(item, after)
    vim.schedule(function()
      if not (item and vim.api.nvim_win_is_valid(win)) then return end
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { item.lnum, 0 })
      if after then after() end
    end)
  end

  -- Exactly one match and the caller said not to bother: a one-item picker
  -- asks a question with a single answer.
  if opts.auto_select and #items == 1 then
    return land_on(items[1], oil.select)
  end

  local dir = oil.get_current_dir(bufnr)
  Snacks.picker({
    title  = opts.title or (dir and vim.fn.fnamemodify(dir, ":~")) or "Oil",
    layout = "select", -- compact centered box (no preview); see snacks layout presets
    -- Return focus to the Oil window (not some other editor window) when the
    -- picker closes. Snacks' default "main" excludes floating windows, so for a
    -- floating Oil it would restore focus to whatever sat behind the float; that
    -- non-float WinEnter trips Oil's float-only auto-close (oil.nvim init.lua's
    -- "Close floating oil window" WinLeave handler), wiping the float out from
    -- under us before the deferred oil.select() below can run. current = true
    -- pins main to the Oil window so the float survives and select() lands.
    main   = { current = true },
    items  = items,
    format = function(item)
      local icon, hl = Snacks.util.icon(item.text, item.dir and "directory" or "file")
      return {
        { icon .. " ", hl },
        { item.text, item.dir and "SnacksPickerDirectory" or "SnacksPickerFile" },
      }
    end,
    -- <CR>: behave exactly like pressing <CR> on the entry in Oil -- land on the
    -- line, then oil.select() (enter dir / open file).
    confirm = function(picker, item)
      picker:close()
      land_on(item, oil.select)
    end,
    -- Named actions, bound below in win.input.keys (rebind via opts.keys).
    actions = {
      -- <S-CR>: jump to the entry -- land the Oil cursor on it WITHOUT opening
      -- (no oil.select), so you can then act on it with the usual Oil keys.
      --
      -- Named `jump` so it displaces snacks' own jump for this picker. That
      -- one wants item.file or item.buf and asserts without either; these
      -- items are Oil lines, not locations, so any default binding the keys
      -- below miss -- after an `opts.keys` rebind, say -- lands here instead.
      jump = function(picker)
        local item = picker:current()
        picker:close()
        land_on(item)
      end,
    },
    win = {
      input = {
        keys = {
          [keys.jump] = { "jump", mode = { "i", "n" }, desc = "jump to entry (no open)" },
        },
      },
      -- The list window carries its own copy of the default keys, where
      -- <S-CR> is snacks' `pick_win` + `jump`. The action above already
      -- claims the `jump` half; binding the key here too drops `pick_win`,
      -- which would otherwise stop to ask which window -- a question with no
      -- answer when all the key does is move a cursor in the Oil buffer.
      list = {
        keys = {
          [keys.jump] = { "jump", desc = "jump to entry (no open)" },
        },
      },
    },
  })
end

return M
