-- bundle_toggle.lua -- enable/disable a NoetherVim bundle by editing
-- the user's init.lua, with diff confirmation. See
-- dev-docs/bundle-toggle-design.md for the design rationale.

local M = {}

---@param category string
---@param name     string
---@return string  -- "noethervim.bundles.<category>.<name>"
function M.module_path(category, name)
  return ("noethervim.bundles.%s.%s"):format(category, name)
end

function M.init_lua_path()
  return vim.fn.stdpath("config") .. "/init.lua"
end

local function read_file(path)
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then return nil, "cannot open " .. path end
  local stat = vim.uv.fs_fstat(fd)
  if not stat then vim.uv.fs_close(fd); return nil, "cannot stat " .. path end
  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  return data
end

local function write_file(path, content)
  local fd = vim.uv.fs_open(path, "w", 420) -- 0644
  if not fd then return false, "cannot open " .. path .. " for writing" end
  vim.uv.fs_write(fd, content, 0)
  vim.uv.fs_close(fd)
  return true
end

-- Escape a module path for use inside a Lua pattern (only `.` is special here).
local function pat_escape(s) return (s:gsub("%.", "%%.")) end

---Find a *commented* `{ import = "<module_path>" }` line.
---@param lines string[]
---@param module_path string
---@return { idx: integer, line: string } | nil
function M.find_commented_import(lines, module_path)
  local needle = '{%s*import%s*=%s*"' .. pat_escape(module_path) .. '"%s*}'
  for i, line in ipairs(lines) do
    if line:match("^%s*%-%-") and line:find(needle) then
      return { idx = i, line = line }
    end
  end
  return nil
end

---Find an *active* (uncommented) `{ import = "<module_path>" }` line.
---@param lines string[]
---@param module_path string
---@return { idx: integer, line: string } | nil
function M.find_active_import(lines, module_path)
  local needle = '{%s*import%s*=%s*"' .. pat_escape(module_path) .. '"%s*}'
  for i, line in ipairs(lines) do
    if not line:match("^%s*%-%-") and line:find(needle) then
      return { idx = i, line = line }
    end
  end
  return nil
end

---Locate the closing `}` of the first `spec = { ... }` table.  Walks lines
---with a brace counter starting at the `spec = {` opener.  Returns the line
---index of the closing brace, or nil if the structure is unrecognizable.
---@param lines string[]
---@return integer | nil
function M.find_spec_block_end(lines)
  local start_idx
  for i, line in ipairs(lines) do
    if line:match("spec%s*=%s*{") then start_idx = i; break end
  end
  if not start_idx then return nil end

  -- Count braces from the spec opener onward, ignoring text after `--`.
  local function strip_comment(s) return (s:gsub("%-%-.*$", "")) end
  local depth = 0
  -- Initialize from the rest of the spec opener line.
  local rest = lines[start_idx]:match("spec%s*=%s*{(.*)$") or ""
  rest = strip_comment(rest)
  -- Account for the opening brace.
  depth = 1
  for c in rest:gmatch("[{}]") do
    if c == "{" then depth = depth + 1 else depth = depth - 1 end
  end
  if depth == 0 then return start_idx end -- single-line spec table

  for i = start_idx + 1, #lines do
    local stripped = strip_comment(lines[i])
    for c in stripped:gmatch("[{}]") do
      if c == "{" then depth = depth + 1 else depth = depth - 1 end
      if depth == 0 then return i end
    end
  end
  return nil
end

---Pick an indent string that matches existing entries inside the spec block.
---Prefers an existing `{ import = ... }` line (commented or active) so the
---inserted line aligns visually.
---@param lines string[]
---@return string
function M.detect_spec_indent(lines)
  for _, line in ipairs(lines) do
    local indent = line:match("^(%s*){%s*import%s*=")
    if indent then return indent end
  end
  for _, line in ipairs(lines) do
    local indent = line:match("^(%s*)%-%-%s*{%s*import%s*=")
    if indent then return indent end
  end
  return "\t\t"
end

---@param module_path string
---@param indent      string|nil
function M.build_import_line(module_path, indent)
  return ("%s{ import = \"%s\" },"):format(indent or "", module_path)
end

---Remove leading "-- " (or "--") from line `idx`, preserving indentation.
function M.uncomment_line(lines, idx)
  local out = {}
  for i, l in ipairs(lines) do out[i] = l end
  out[idx] = out[idx]:gsub("^(%s*)%-%-%s?", "%1", 1)
  return out
end

---Insert "-- " after the leading indent of line `idx`.
function M.comment_line(lines, idx)
  local out = {}
  for i, l in ipairs(lines) do out[i] = l end
  out[idx] = out[idx]:gsub("^(%s*)", "%1-- ", 1)
  return out
end

---Insert `new_line` so it occupies position `before_idx` (existing line slides
---down).
function M.insert_before(lines, before_idx, new_line)
  local out = {}
  for i, l in ipairs(lines) do out[i] = l end
  table.insert(out, before_idx, new_line)
  return out
end

---Render a unified diff between two line lists. Adds a `--- path` / `+++ path`
---header.
---@param before string[]
---@param after  string[]
---@param path   string
---@return string
function M.unified_diff(before, after, path)
  local before_str = table.concat(before, "\n") .. "\n"
  local after_str  = table.concat(after,  "\n") .. "\n"
  local body = vim.diff(before_str, after_str, { result_type = "unified", ctxlen = 3 })
  local header = ("--- %s\n+++ %s\n"):format(path, path)
  return header .. (body or "")
end

---Split file content into lines, dropping the trailing empty element produced
---by a final `\n`.  Returns the lines and a flag indicating whether the
---original ended with a newline so we can preserve it on write-back.
local function split_lines(content)
  local lines = vim.split(content, "\n", { plain = true })
  local trailing_nl = false
  if lines[#lines] == "" then
    table.remove(lines)
    trailing_nl = true
  end
  return lines, trailing_nl
end

local function join_lines(lines, trailing_nl)
  local out = table.concat(lines, "\n")
  if trailing_nl then out = out .. "\n" end
  return out
end

---Try to enable a bundle.  Runs the ladder: uncomment-in-place ->
---spec-block insert -> fallback to copy.  Shows a diff modal for the first
---two; the fallback writes to registers and notifies.
---@param category string
---@param name     string
function M.enable(category, name)
  local module_path = M.module_path(category, name)
  local path = M.init_lua_path()
  local content, err = read_file(path)
  if not content then
    return vim.notify("NoetherVim: " .. err, vim.log.levels.ERROR)
  end
  local lines, trailing_nl = split_lines(content)

  local new_lines, op
  local hit = M.find_commented_import(lines, module_path)
  if hit then
    new_lines = M.uncomment_line(lines, hit.idx)
    op = "uncomment"
  else
    local end_idx = M.find_spec_block_end(lines)
    if end_idx then
      local indent = M.detect_spec_indent(lines)
      local new_line = M.build_import_line(module_path, indent)
      new_lines = M.insert_before(lines, end_idx, new_line)
      op = "insert"
    end
  end

  if not new_lines then
    -- Fallback: copy the import line to registers.
    local snippet = M.build_import_line(module_path, "")
    vim.fn.setreg("+", snippet)
    vim.fn.setreg('"', snippet)
    vim.notify(
      ("NoetherVim: could not modify init.lua automatically.\n" ..
       "Add this line to your spec block (copied to + and \" registers):\n  %s"):format(snippet),
      vim.log.levels.WARN
    )
    return
  end

  local diff = M.unified_diff(lines, new_lines, path)
  require("noethervim.util.diff_modal").confirm({
    title   = ("Enable bundle: %s (%s)"):format(name, op),
    diff    = diff,
    on_done = function(accepted)
      if not accepted then
        vim.notify("NoetherVim: bundle enable cancelled", vim.log.levels.INFO)
        return
      end
      local ok, werr = write_file(path, join_lines(new_lines, trailing_nl))
      if not ok then return vim.notify("NoetherVim: " .. werr, vim.log.levels.ERROR) end
      vim.notify(
        ("NoetherVim: bundle %q enabled.\n" ..
         "Restart Neovim to load it (or :Lazy reload if you know what you're doing)."):format(name),
        vim.log.levels.INFO
      )
    end,
  })
end

---Disable a bundle by re-commenting its active import line.
---@param category string
---@param name     string
function M.disable(category, name)
  local module_path = M.module_path(category, name)
  local path = M.init_lua_path()
  local content, err = read_file(path)
  if not content then
    return vim.notify("NoetherVim: " .. err, vim.log.levels.ERROR)
  end
  local lines, trailing_nl = split_lines(content)

  local hit = M.find_active_import(lines, module_path)
  if not hit then
    vim.notify(
      ("NoetherVim: bundle %q is not enabled via init.lua " ..
       "(loaded via another mechanism, or already disabled?)"):format(name),
      vim.log.levels.WARN
    )
    return
  end

  local new_lines = M.comment_line(lines, hit.idx)
  local diff = M.unified_diff(lines, new_lines, path)
  require("noethervim.util.diff_modal").confirm({
    title   = ("Disable bundle: %s"):format(name),
    diff    = diff,
    on_done = function(accepted)
      if not accepted then
        vim.notify("NoetherVim: bundle disable cancelled", vim.log.levels.INFO)
        return
      end
      local ok, werr = write_file(path, join_lines(new_lines, trailing_nl))
      if not ok then return vim.notify("NoetherVim: " .. werr, vim.log.levels.ERROR) end
      vim.notify(
        ("NoetherVim: bundle %q disabled.\n" ..
         "Restart Neovim for the change to take effect."):format(name),
        vim.log.levels.INFO
      )
    end,
  })
end

return M
