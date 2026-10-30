--- The one-time notice a bundle asks for with `---@recommended ft=<ft>`: on
--- the first buffer of that filetype in an install without the bundle, say
--- what it adds and offer the change to init.lua that enables it. Nothing is
--- enabled without that diff's go-ahead.
---
--- Each bundle is offered once, ever: shown is recorded in
--- stdpath("state")/noethervim/recommended, outside your config. Headless
--- sessions never show it.

local M = {}

local state_file = vim.fn.stdpath("state") .. "/noethervim/recommended"

---@return table<string, true> bundle keys ("languages.latex") already offered
local function offered()
  local out = {}
  if vim.fn.filereadable(state_file) == 1 then
    for _, key in ipairs(vim.fn.readfile(state_file)) do out[key] = true end
  end
  return out
end

---@param key string
local function mark(key)
  local keys = vim.tbl_keys(offered())
  table.insert(keys, key)
  table.sort(keys)
  vim.fn.mkdir(vim.fs.dirname(state_file), "p")
  vim.fn.writefile(keys, state_file)
end

--- Bundles not enabled and not yet offered, by the filetypes they ask for.
--- Read from the bundle headers once, the first time a filetype is opened.
---@type table<string, noethervim.BundleMeta[]>?
local by_ft

local function scan()
  by_ft = {}
  local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
  if not init then return end
  local enabled, done = {}, offered()
  for _, mod in ipairs(require("lazy.core.config").spec.modules or {}) do
    local key = mod:match("^noethervim%.bundles%.(.+)$")
    if key then enabled[key] = true end
  end
  local bundles = vim.fn.fnamemodify(init, ":h") .. "/bundles"
  for _, meta in ipairs(require("noethervim.util.bundle_meta").scan(bundles)) do
    local key = meta.category .. "." .. meta.name
    if meta.recommended and not enabled[key] and not done[key] then
      for _, ft in ipairs(meta.recommended) do
        by_ft[ft] = by_ft[ft] or {}
        table.insert(by_ft[ft], meta)
      end
    end
  end
end

--- Wrap `text` to `width` columns.
local function wrap(text, width)
  local lines, line = {}, ""
  for word in text:gmatch("%S+") do
    if #line + #word + 1 > width and line ~= "" then
      table.insert(lines, line)
      line = word
    else
      line = line == "" and word or (line .. " " .. word)
    end
  end
  if line ~= "" then table.insert(lines, line) end
  return lines
end

---@param meta noethervim.BundleMeta
local function show(meta)
  local key = meta.category .. "." .. meta.name
  mark(key)
  local width = math.min(68, vim.o.columns - 8)
  local lines = { ("The %s bundle is not enabled. It adds:"):format(meta.name), "" }
  vim.list_extend(lines, wrap(meta.about or meta.desc or "", width))
  vim.list_extend(lines, {
    "",
    "<CR>   show the change to init.lua that enables it",
    "<Esc>  close; :NoetherVim bundles lists every bundle",
    "",
    "This shows once.",
  })
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded",
    title = " NoetherVim ", title_pos = "center",
    width = width + 2, height = #lines,
    row = math.floor((vim.o.lines - #lines) / 2) - 1,
    col = math.floor((vim.o.columns - width - 2) / 2),
  })
  vim.wo[win].wrap = true
  local function close()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  vim.keymap.set("n", "<CR>", function()
    close()
    require("noethervim.util.bundle_toggle").enable(meta.category, meta.name)
  end, { buf = buf, nowait = true, desc = "review and enable the bundle" })
  for _, lhs in ipairs({ "<Esc>", "q" }) do
    vim.keymap.set("n", lhs, close, { buf = buf, nowait = true, desc = "close" })
  end
end

--- Offer the first not-yet-offered bundle that recommends itself for `ft`.
---@param ft string
function M.check(ft)
  if not by_ft then scan() end
  local list = by_ft and by_ft[ft]
  local meta = list and table.remove(list, 1)
  if meta then show(meta) end
end

--- Watch for the first buffer of a filetype a missing bundle asks for.
function M.setup()
  local checked = {} ---@type table<string, true>
  vim.api.nvim_create_autocmd("FileType", {
    group    = vim.api.nvim_create_augroup("noethervim.recommend", { clear = true }),
    callback = function(ev)
      local ft = ev.match
      if checked[ft] or vim.bo[ev.buf].buftype ~= "" then return end
      checked[ft] = true
      -- After the buffer is on screen: the scan reads every bundle header.
      vim.schedule(function() M.check(ft) end)
    end,
  })
end

return M
