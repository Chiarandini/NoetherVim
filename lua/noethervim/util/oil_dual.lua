--- Dual-pane Oil: two directories side by side, for moving files between
--- them.
---
--- The job this exists for is "take these files and put them over there".
--- That wants both ends visible at once, each navigable on its own, so you
--- can yank in one pane and paste in the other.
---
--- What this replaces asked for the destination up front, through a picker
--- running `fd --type d` rooted at the *source* directory. Copying to a
--- sibling -- `src/` to `dst/`, the ordinary case -- was therefore not
--- expressible: the picker could only offer directories below where you
--- already were. Opening the second pane at the same directory and letting
--- Oil navigate it removes that at the root rather than widening the search,
--- and navigating with Oil is what you wanted the pane for anyway.

local M = {}

local group = vim.api.nvim_create_augroup("noethervim_oil_dual", { clear = true })

---@param win integer
---@return boolean
local function is_float(win)
  return vim.api.nvim_win_get_config(win).relative ~= ""
end

--- Tie two windows together: closing either closes the other, and the pair
--- stops being tracked. Oil replaces its buffer on every navigation, so this
--- is keyed on window ids, which survive it -- the previous version bound a
--- close key to the buffer, and the binding was lost the moment you entered
--- a directory.
---@param a integer
---@param b integer
local function link(a, b)
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      local closed = tonumber(ev.match)
      if closed ~= a and closed ~= b then return end
      local other = closed == a and b or a
      -- Scheduled: closing from inside the handler for the same event loop
      -- tick fights Oil's own teardown.
      vim.schedule(function()
        if not vim.api.nvim_win_is_valid(other) then return end
        -- The survivor may be the only window left, and Neovim will not
        -- close that -- E444. Which is right: "close the pair" means leave
        -- dual-pane mode, not leave the editor. So hand the window back to
        -- Oil, which restores whatever buffer it was showing before, and the
        -- result is the single window you started from.
        if not pcall(vim.api.nvim_win_close, other, true) then
          pcall(vim.api.nvim_win_call, other, function()
            pcall(require("oil").close)
          end)
        end
      end)
      M._pair = nil
      return true -- one-shot; the pair is gone either way
    end,
  })
end

--- `<C-h>` / `<C-l>` between the two panes, and `q` to close both.
---
--- Both targets are resolved when the key is pressed, from the window you are
--- standing in -- NOT captured when the mapping is made.
---
--- That distinction is the whole of it. The panes open at the same directory,
--- and Oil serves one buffer per directory, so both windows show the SAME
--- buffer. A buffer-local mapping is therefore set twice over, and a captured
--- target means the second write wins: `<C-l>` aimed at one fixed window
--- whichever pane you were in, so from that window it did nothing at all.
---@param a integer
---@param b integer
local function bind(a, b)
  local function other_pane()
    local cur = vim.api.nvim_get_current_win()
    local other = cur == a and b or a
    -- Standing outside the pair (a stray split) should not teleport you.
    if cur ~= a and cur ~= b then return nil end
    return vim.api.nvim_win_is_valid(other) and other or nil
  end

  local function apply()
    for _, win in ipairs({ a, b }) do
      if vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        local opts = { buffer = buf, nowait = true, silent = true }
        local function focus()
          local other = other_pane()
          if other then vim.api.nvim_set_current_win(other) end
        end
        vim.keymap.set("n", "<c-h>", focus, vim.tbl_extend("force", opts, { desc = "other Oil pane" }))
        vim.keymap.set("n", "<c-l>", focus, vim.tbl_extend("force", opts, { desc = "other Oil pane" }))
        vim.keymap.set("n", "q", function()
          pcall(vim.api.nvim_win_close, vim.api.nvim_get_current_win(), true)
        end, vim.tbl_extend("force", opts, { desc = "close both Oil panes" }))
      end
    end
  end

  apply()
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function()
      local cur = vim.api.nvim_get_current_win()
      if cur ~= a and cur ~= b then return end
      if not (vim.api.nvim_win_is_valid(a) and vim.api.nvim_win_is_valid(b)) then
        return true
      end
      vim.schedule(apply)
    end,
  })
end

--- Open a second Oil pane beside the current one, at the same directory.
---
--- The new pane matches the shape of the one you were in: a float begets two
--- floats, a normal window begets a vertical split. Mixing them would leave
--- a float covering the split it was supposed to sit beside.
--- The pair currently open, so `gV` can toggle rather than stack panes.
---@type integer[]|nil
M._pair = nil

--- True when `win` belongs to the live pair.
local function in_pair(win)
  if not M._pair then return false end
  for _, w in ipairs(M._pair) do
    if w == win and vim.api.nvim_win_is_valid(w) then return true end
  end
  return false
end

--- Leave dual-pane mode: close one pane and let `link` take the other with
--- it, which is the same path `q` uses.
local function close_pair()
  local pair = M._pair
  M._pair = nil
  if not pair then return end
  for _, w in ipairs(pair) do
    if vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
      return
    end
  end
end

function M.open()
  local oil = require("oil")
  local cur = vim.api.nvim_get_current_win()

  -- Pressing it again leaves, rather than opening a third pane beside the
  -- two already there.
  if in_pair(cur) then return close_pair() end

  local dir = oil.get_current_dir()
  if not dir then return end

  if not is_float(cur) then
    -- Window case: a plain vsplit is the whole of it, and Oil's own
    -- navigation then applies to each side independently.
    vim.cmd("vsplit")
    oil.open(dir)
    local right = vim.api.nvim_get_current_win()
    link(cur, right)
    bind(cur, right)
    M._pair = { cur, right }
    return
  end

  -- Float case. Oil's own float is centred and full-width, so it cannot
  -- simply be halved in place without the second pane overlapping it; close
  -- it and lay two out together.
  oil.close()
  vim.schedule(function()
    local total_w = math.floor(vim.o.columns * 0.9)
    local total_h = math.floor(vim.o.lines * 0.8)
    local row     = math.floor((vim.o.lines - total_h) / 2)
    local col0    = math.floor((vim.o.columns - total_w) / 2)
    local half_w  = math.floor((total_w - 2) / 2)

    local wins = {}
    for idx = 0, 1 do
      local buf = vim.api.nvim_create_buf(false, true)
      wins[#wins + 1] = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style    = "minimal",
        border   = "rounded",
        row      = row,
        col      = col0 + idx * (half_w + 2),
        width    = half_w,
        height   = total_h,
      })
      oil.open(dir)
    end

    link(wins[1], wins[2])
    bind(wins[1], wins[2])
    M._pair = { wins[1], wins[2] }
    -- Land in the left pane: it is the one you were looking at, and reading
    -- left to right is the direction the copy usually goes.
    if vim.api.nvim_win_is_valid(wins[1]) then
      vim.api.nvim_set_current_win(wins[1])
    end
  end)
end

return M
