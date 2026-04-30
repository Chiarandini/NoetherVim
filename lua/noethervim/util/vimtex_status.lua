-- VimTeX statusline helpers.
--
-- Shared between the heirline `VimtexCompilerStatus` and `PdfFileSize`
-- components.  Resolves the most relevant vimtex state for a buffer
-- (handling input files and subfile parent/child split), exposes the
-- correct PDF path for that state, and persists a single per-project
-- baseline (last successful PDF size + compile duration) so the
-- statusline can render a rough completion percentage on the next
-- compile.

---@class vimtex_status
local M = {}

-- ── Baseline cache ────────────────────────────────────────────────────────
-- One record per absolute main-tex path, overwritten on each
-- VimtexEventCompileSuccess.  We keep only the most recent compile --
-- older sizes are dead weight.

local cache_dir  = vim.fn.stdpath("state") .. "/noethervim"
local cache_path = cache_dir .. "/vimtex_baseline.json"

---@type table<string, { size: integer, ms: integer, at: integer }> | nil
local cache_data = nil

local function load_cache()
  if cache_data then return cache_data end
  cache_data = {}
  local f = io.open(cache_path, "r")
  if not f then return cache_data end
  local raw = f:read("*a")
  f:close()
  if not raw or raw == "" then return cache_data end
  local ok, decoded = pcall(vim.json.decode, raw)
  if ok and type(decoded) == "table" then
    -- Hygiene: drop entries whose tex file no longer exists.
    for path, entry in pairs(decoded) do
      if type(path) == "string" and type(entry) == "table"
          and vim.uv.fs_stat(path) then
        cache_data[path] = entry
      end
    end
  end
  return cache_data
end

local function save_cache()
  if not cache_data then return end
  vim.fn.mkdir(cache_dir, "p")
  local ok, encoded = pcall(vim.json.encode, cache_data)
  if not ok then return end
  local f = io.open(cache_path, "w")
  if not f then return end
  f:write(encoded)
  f:close()
end

-- ── State selection ───────────────────────────────────────────────────────
-- Per-buffer cache keyed by changedtick so we don't iterate
-- `vimtex#state#get_all()` on every redraw.

---@type table<integer, { tick: integer, result: table | false }>
local pick_cache = {}

local function get_state(id)
  local ok, state = pcall(vim.fn["vimtex#state#get"], id)
  if ok and type(state) == "table" then return state end
  return nil
end

---@param state table | nil
---@return boolean
local function state_has_compiler(state)
  return state ~= nil and type(state.compiler) == "table"
end

---@param state table | nil
---@return integer  -- 0 idle, 1 compiling, 2 success, 3 failure
local function state_status(state)
  if not state_has_compiler(state) then return 0 end
  ---@cast state table
  return tonumber(state.compiler.status) or 0
end

-- Walk every known vimtex state and return the first whose source
-- list contains `path`.  Used as a last-resort fallback for orphan
-- input files that have no main-file marker.  vimtex returns sources
-- as paths relative to `state.root` (autoload/vimtex/state/class.vim
-- gather_sources), so we resolve them to absolute before comparing.
local function find_owner(path)
  local target = vim.fs.normalize(path)
  local ok, all = pcall(vim.fn["vimtex#state#get_all"])
  if not ok or type(all) ~= "table" then return nil end
  for _, state in pairs(all) do
    if type(state) == "table" then
      if type(state.tex) == "string" and vim.fs.normalize(state.tex) == target then
        return state
      end
      local root = type(state.root) == "string" and state.root or ""
      local sources
      if type(state.get_sources) == "function" then
        local sok, srcs = pcall(state.get_sources, state)
        if sok and type(srcs) == "table" then sources = srcs end
      end
      if sources then
        for _, src in ipairs(sources) do
          local abs = src
          if not src:match("^/") and root ~= "" then
            abs = root .. "/" .. src
          end
          if vim.fs.normalize(abs) == target then return state end
        end
      end
    end
  end
  return nil
end

---Return the {parent, sub, active} states for a buffer.  Any may be nil.
---`active` is whichever vimtex currently routes `b:vimtex` to.
---@param bufnr integer
---@return { parent: table | nil, sub: table | nil, active: table | nil }
function M.states(bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  local ok_b, b = pcall(vim.api.nvim_buf_get_var, bufnr, "vimtex")
  local active = (ok_b and type(b) == "table") and b or nil

  local ok_l, bl = pcall(vim.api.nvim_buf_get_var, bufnr, "vimtex_local")
  if ok_l and type(bl) == "table" then
    return {
      parent = get_state(bl.main_id),
      sub    = get_state(bl.sub_id),
      active = active,
    }
  end

  -- No subfile split.  If the active state has no compiler attached
  -- (orphan input file with its own auto-created state), look for a
  -- project that actually owns this file.
  if not state_has_compiler(active) then
    local path  = vim.api.nvim_buf_get_name(bufnr)
    local owner = path ~= "" and find_owner(path) or nil
    if owner then
      return { parent = owner, sub = nil, active = active }
    end
  end

  return { parent = nil, sub = nil, active = active }
end

---Pick the single state whose status is most worth surfacing.
---Caches per (bufnr, changedtick).
---@param bufnr integer
---@return { state: table, role: "active" | "parent" | "sub", parent_compiling: boolean, sub_compiling: boolean } | nil
function M.pick(bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local hit  = pick_cache[bufnr]
  if hit and hit.tick == tick then
    return hit.result or nil
  end

  local s = M.states(bufnr)
  local parent_running = state_status(s.parent) == 1
  local sub_running    = state_status(s.sub)    == 1

  local chosen, role
  if parent_running and not sub_running then
    chosen, role = s.parent, "parent"
  elseif sub_running and not parent_running then
    chosen, role = s.sub, "sub"
  elseif parent_running and sub_running then
    chosen, role = s.parent, "parent"  -- both: parent wins for label, both flagged
  elseif state_has_compiler(s.active) then
    chosen = s.active
    if s.parent and s.active == s.parent then role = "parent"
    elseif s.sub and s.active == s.sub then role = "sub"
    else role = "active" end
  elseif state_has_compiler(s.parent) then
    chosen, role = s.parent, "parent"
  elseif state_has_compiler(s.sub) then
    chosen, role = s.sub, "sub"
  end

  local result
  if chosen then
    result = {
      state            = chosen,
      role             = role,
      parent_compiling = parent_running,
      sub_compiling    = sub_running,
    }
  end
  pick_cache[bufnr] = { tick = tick, result = result or false }
  return result
end

---Invalidate the pick cache (call from VimtexEventInitPost / autocmd hooks).
function M.invalidate(bufnr)
  if bufnr then pick_cache[bufnr] = nil else pick_cache = {} end
end

-- ── PDF path resolution ───────────────────────────────────────────────────

---Return the absolute PDF path for `state`, or nil if it can't be resolved.
---Goes through `state.compiler.get_file('pdf')` (which respects out_dir,
---aux_dir, and -jobname overrides) and falls back to `<root>/<name>.pdf`.
---@param state table
---@return string | nil
function M.pdf_path(state)
  if state_has_compiler(state) and type(state.compiler.get_file) == "function" then
    local ok, path = pcall(state.compiler.get_file, state.compiler, "pdf")
    if ok and type(path) == "string" and path ~= "" then return path end
  end
  if type(state.root) == "string" and type(state.name) == "string" then
    return state.root .. "/" .. state.name .. ".pdf"
  end
  return nil
end

---@param path string | nil
---@return integer  bytes; 0 if missing
local function file_size(path)
  if not path then return 0 end
  local stat = vim.uv.fs_stat(path)
  return (stat and stat.size) or 0
end

-- ── Baseline read/write ───────────────────────────────────────────────────

---@param state table
---@return string | nil
local function baseline_key(state)
  return type(state.tex) == "string" and state.tex or nil
end

---@param state table
---@return { size: integer, ms: integer, at: integer } | nil
function M.baseline(state)
  local key = baseline_key(state)
  if not key then return nil end
  return load_cache()[key]
end

---Record a successful compile in the cache.
---@param state table
---@param compile_ms integer
function M.record_success(state, compile_ms)
  local key = baseline_key(state)
  if not key then return end
  local pdf  = M.pdf_path(state)
  local size = file_size(pdf)
  if size <= 0 then return end
  local data = load_cache()
  data[key] = {
    size = size,
    ms   = compile_ms,
    at   = os.time(),
  }
  save_cache()
end

-- ── Progress label ────────────────────────────────────────────────────────

---Human label for a state currently compiling.  Returns "compiling…",
---"compiling 42%", or "compiling 102% — almost done".  Percentage is
---clamped to 95 until success fires, so a stalled bar doesn't sit at 99.
---Returns a raw string with literal `%`; statusline consumers must
---escape it via `escape_percent` because vim's statusline syntax
---treats `%` as a directive prefix.
---@param state table
---@return string
function M.progress_label(state)
  local baseline = M.baseline(state)
  if not baseline or baseline.size <= 0 then return "compiling…" end
  local current = file_size(M.pdf_path(state))
  if current <= 0 then return "compiling…" end
  local pct = math.floor((current / baseline.size) * 100 + 0.5)
  if pct <= 100 then
    return string.format("compiling %d%%", math.min(pct, 95))
  elseif pct <= 130 then
    return string.format("compiling %d%% — almost done", pct)
  else
    return "compiling — wrapping up"
  end
end

---Double `%` so a string is safe to embed in a statusline expression.
---@param s string
---@return string
function M.escape_percent(s)
  return (s:gsub("%%", "%%%%"))
end

return M
