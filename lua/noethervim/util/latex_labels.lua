-- noethervim.util.latex_labels
--
-- Label navigation and completion documentation for the latex bundle,
-- built on the label cache maintained by snacks-latex-labels /
-- latex-nav-core. Consumed by three wirings in the latex bundle:
--
--   gd        goto label definition (cache first, LSP fallback)
--   'tagfunc' <C-]> / <C-w>] / :tag jump to labels via the tag stack
--   blink.cmp resolve override on the vimtex source -- hovering a label
--             completion shows its part/chapter/section and LaTeX source
--
-- Every entry point degrades gracefully (nil / LSP fallback) when
-- latex-nav-core isn't on the runtimepath yet.

local M = {}

-- Matches the smart_jump_window passed to snacks-latex-labels in the bundle.
local SMART_JUMP_WINDOW = 200

-- Lines above a bare \label{} to search for its enclosing \begin{env}.
local BODY_LOOKBACK = 10

-- Cap on documentation body length; huge environments get truncated.
local BODY_MAX_LINES = 40

---Extract the prefixed label under the cursor, e.g. "th:bezoutIdentity"
---from \cref{th:bezoutIdentity}.
---@return string|nil
function M.label_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col  = vim.api.nvim_win_get_cursor(0)[2] + 1  -- 1-indexed
  -- Walk every "prefix:name" token in the line; return the one under cursor.
  local pos = 1
  while true do
    local s, e, label = line:find("(%a+:%a[%a%d%-_%.]*)", pos)
    if not s then break end
    if col >= s and col <= e then return label end
    pos = e + 1
  end
  return nil
end

---Look up `label` in the label caches: the current project first (root
---detection climbs `subfiles` chains, so sub-books resolve to their
---top-level root), then every other cached project. The returned entry's
---line is re-verified against the file so a stale cache still lands on
---the label.
---Cache strategy is hardcoded to "global" -- update if you override
---cache_strategy in the snacks-latex-labels setup.
---@param label string
---@return { line: integer, id: string, context: string, filename: string }|nil
function M.find_entry(label)
  local ok, cache = pcall(require, "latex_nav_core.latex_labels.cache")
  if not ok then return nil end
  local utils = require("latex_nav_core.latex")

  local function search(path)
    local entries = cache.read_cache(path)
    if not entries then return nil end
    for _, e in ipairs(entries) do
      -- Skip entries whose file no longer exists: caches are keyed by root
      -- path and persist across project moves, so the fallback scan below
      -- walks historical caches full of dead paths.
      if e.id == label and vim.uv.fs_stat(e.filename) then return e end
    end
  end

  local root = utils.get_root_file()
  local current_cache = root and cache.get_cache_path(root, "global") or nil
  local entry = current_cache and search(current_cache) or nil

  -- Label not in the current project -- search all other cached projects.
  -- Covers cross-book references once those books have been indexed.
  if not entry then
    local cache_dir = vim.fn.stdpath("data") .. "/cached_labels"
    for _, path in ipairs(vim.fn.glob(cache_dir .. "/*.labels", false, true)) do
      if path ~= current_cache then
        entry = search(path)
        if entry then break end
      end
    end
  end
  if not entry then return nil end

  local verified = utils.verify_or_find_label(entry.filename, entry.line, entry.id, SMART_JUMP_WINDOW)
  if verified then entry.line = verified end
  return entry
end

---'tagfunc' for tex buffers: jumping to a \cref/\ref/\eqref argument goes
---through the label cache (pushing the tag stack, so <C-t> returns).
---Anything that isn't a cached label falls through to the LSP tagfunc,
---then to regular tags.
function M.tagfunc(pattern, flags, _info)
  -- 'c': invoked from normal mode (<C-]> and friends), so the cursor
  -- position is available and more precise than the iskeyword-based
  -- pattern (labels may contain '-' and '.').
  local label = flags:find("c") and M.label_at_cursor() or pattern
  if label then
    local entry = M.find_entry(label)
    if entry then
      return { { name = entry.id, filename = entry.filename, cmd = tostring(entry.line) } }
    end
  end
  local ok, matches = pcall(vim.lsp.tagfunc, pattern, flags)
  if ok and type(matches) == "table" and #matches > 0 then return matches end
  return vim.NIL
end

---Read lines [first, last] (1-based, inclusive) from `filepath`, using the
---loaded buffer when available so unsaved edits are respected.
---@param filepath string
---@param first integer
---@param last integer  May be math.huge to read to the end of the file.
---@return string[]
local function read_lines(filepath, first, last)
  local bufnr = vim.fn.bufnr(filepath)
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, first - 1, last == math.huge and -1 or last, false)
  end
  local lines = {}
  local f = io.open(filepath, "r")
  if not f then return lines end
  local lnum = 0
  for line in f:lines() do
    lnum = lnum + 1
    if lnum > last then break end
    if lnum >= first then table.insert(lines, line) end
  end
  f:close()
  return lines
end

---Extract the environment enclosing `lnum` as a source snippet. The label
---line either is the \begin line itself (\begin{thm}{Title}{label}) or
---sits a few lines inside the environment (\label{eq:x} in an align
---block). Falls back to a few raw lines when no environment is found
---(e.g. a \label right after \section{...}).
---@param filepath string
---@param lnum integer
---@return string[]
local function body_snippet(filepath, lnum)
  local first = math.max(1, lnum - BODY_LOOKBACK)
  local lines = read_lines(filepath, first, lnum + BODY_MAX_LINES)
  local label_idx = lnum - first + 1

  -- Nearest \begin{env} at or above the label line.
  local begin_idx, env
  for i = math.min(label_idx, #lines), 1, -1 do
    env = lines[i] and lines[i]:match("\\begin%s*{(%w+%*?)}")
    if env then
      begin_idx = i
      break
    end
  end
  if not begin_idx then
    return vim.list_slice(lines, label_idx, math.min(#lines, label_idx + 7))
  end

  -- Matching \end{env}, counting nested environments of the same name.
  local depth = 0
  for i = begin_idx, #lines do
    for _ in lines[i]:gmatch("\\begin%s*{" .. vim.pesc(env) .. "}") do depth = depth + 1 end
    for _ in lines[i]:gmatch("\\end%s*{" .. vim.pesc(env) .. "}") do depth = depth - 1 end
    if depth == 0 then
      return vim.list_slice(lines, begin_idx, i)
    end
  end
  local snippet = vim.list_slice(lines, begin_idx, #lines)
  table.insert(snippet, "...")
  return snippet
end

---Sectioning headings (part/chapter/section/...) in `filepath` at or above
---line `stop`, in document order.
---@param filepath string
---@param stop integer
---@return { line: integer, level: integer, kind: string, title: string }[]
local function headings_above(filepath, stop)
  local ok, parser = pcall(require, "latex_nav_core.cached_headings.parser")
  if not ok then return {} end
  local out = {}
  for _, h in ipairs(parser.scan_file(filepath, "tex", { include_starred = true })) do
    if h.line > stop then break end
    table.insert(out, h)
  end
  return out
end

---Line in `parent` whose \input / \include / \subfile resolves to `child`.
---Arguments resolve relative to the parent's directory, matching how
---subfile roots include their children.
---@param parent string
---@param child string
---@return integer|nil
local function include_line(parent, child)
  local dir = vim.fn.fnamemodify(parent, ":h")
  for i, line in ipairs(read_lines(parent, 1, math.huge)) do
    local inc = line:match("\\input%s*{(.-)}")
             or line:match("\\include%s*{(.-)}")
             or line:match("\\subfile%s*{(.-)}")
    if inc and vim.trim(inc) ~= "" then
      local path = dir .. "/" .. vim.trim(inc)
      if not path:match("%.%w+$") then path = path .. ".tex" end
      if vim.fn.fnamemodify(path, ":p") == child then return i end
    end
  end
  return nil
end

---Chain of files from the top-level root down to `filepath`, following
---\documentclass[..]{subfiles} upward. Includes `filepath` itself as the
---last element.
---@param filepath string
---@return string[]
local function root_chain(filepath)
  local utils = require("latex_nav_core.latex")
  local chain, seen = { filepath }, { [filepath] = true }
  local file = filepath
  while true do
    local parent = utils.find_root_via_subfiles(file)
    if not parent or seen[parent] then break end
    seen[parent] = true
    table.insert(chain, 1, parent)
    file = parent
  end
  return chain
end

---Markdown documentation for a label entry: the part/chapter/section it
---lives under, followed by the LaTeX source of its environment (theorem
---statement, titled box, equation, ...).
---@param entry { line: integer, id: string, context: string, filename: string }
---@return string|nil
function M.documentation(entry)
  -- Heading chain: walk root -> ... -> entry file, collecting headings
  -- above each include hand-off, then above the label itself. One stack
  -- keyed by level reproduces document order across files.
  local chain = {}
  local files = root_chain(entry.filename)
  for i, file in ipairs(files) do
    local stop = (i == #files) and entry.line or include_line(file, files[i + 1])
    if stop then
      for _, h in ipairs(headings_above(file, stop)) do
        chain[h.level] = h
        for lvl = h.level + 1, 5 do chain[lvl] = nil end
      end
    end
  end

  local parts = {}
  for lvl = 1, 5 do
    local h = chain[lvl]
    if h then
      table.insert(parts, h.kind:sub(1, 1):upper() .. h.kind:sub(2) .. ": " .. h.title)
    end
  end

  local body = body_snippet(entry.filename, entry.line)
  if #parts == 0 and #body == 0 then return nil end

  local out = {}
  if #parts > 0 then
    table.insert(out, "**" .. table.concat(parts, " > ") .. "**")
  end
  if #body > 0 then
    if #out > 0 then table.insert(out, "") end
    table.insert(out, "```latex")
    vim.list_extend(out, body)
    table.insert(out, "```")
  end
  return table.concat(out, "\n")
end

return M
