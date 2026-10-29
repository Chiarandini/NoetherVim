-- Generate the `.tutor.json` sidecars from tutor/answers.lua.
--
--   nvim --headless -l tools/gen-tutor-json.lua          write the sidecars
--   nvim --headless -l tools/gen-tutor-json.lua --check  fail if they drift
--
-- Neovim's tutor checks an exercise line by its ABSOLUTE line number, held in
-- a separate JSON file. Editing a lesson's prose shifts every number below the
-- edit and silently detaches each check from the line it belongs to, with no
-- error to notice. So the numbers are never written by hand: answers.lua keys
-- each exercise by the placeholder text shipped on that line, which survives
-- edits elsewhere in the file, and this script resolves those to line numbers.
--
-- Rewriting a placeholder itself is a hard error rather than a silent miss.

local root      = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, "S").source:sub(2)), ":h:h")
local tutor_dir = root .. "/tutor"
local check     = vim.tbl_contains(vim.v.argv, "--check")

local answers = dofile(tutor_dir .. "/answers.lua")

--- Emit JSON by hand: `vim.json.encode` orders string keys arbitrarily, which
--- would churn the committed file and make the --check diff meaningless.
---@param pairs_ table[] { lnum, expected }
---@return string
local function encode(pairs_)
  table.sort(pairs_, function(a, b) return a[1] < b[1] end)
  local out = { "{", '  "expect": {' }
  for i, p in ipairs(pairs_) do
    local value = p[2] == -1 and "-1" or vim.json.encode(p[2])
    out[#out + 1] = ('    "%d": %s%s'):format(p[1], value, i < #pairs_ and "," or "")
  end
  out[#out + 1] = "  }"
  out[#out + 1] = "}"
  return table.concat(out, "\n") .. "\n"
end

local failures, written, checked = {}, 0, 0

for _, lesson in ipairs(vim.tbl_keys(answers)) do
  local tutor_path = ("%s/%s.tutor"):format(tutor_dir, lesson)
  local json_path  = tutor_path .. ".json"

  local fd = io.open(tutor_path, "r")
  if not fd then
    failures[#failures + 1] = ("%s: no such lesson file"):format(lesson)
    goto continue
  end
  local lines = vim.split(fd:read("*a"), "\n", { plain = true })
  fd:close()

  local resolved = {}
  for _, entry in ipairs(answers[lesson]) do
    local placeholder, expected = entry[1], entry[2]
    local hits = {}
    for lnum, text in ipairs(lines) do
      if text == placeholder then hits[#hits + 1] = lnum end
    end
    if #hits == 0 then
      failures[#failures + 1] =
        ("%s: placeholder not found: %q"):format(lesson, placeholder)
    elseif #hits > 1 then
      failures[#failures + 1] =
        ("%s: placeholder is ambiguous (lines %s): %q")
          :format(lesson, table.concat(hits, ", "), placeholder)
    else
      resolved[#resolved + 1] = { hits[1], expected }
    end
  end

  local body = encode(resolved)
  if check then
    local cur = io.open(json_path, "r")
    local existing = cur and cur:read("*a") or nil
    if cur then cur:close() end
    if existing ~= body then
      failures[#failures + 1] = ("%s: sidecar is stale, re-run tools/gen-tutor-json.lua"):format(lesson)
    end
    checked = checked + 1
  else
    local out = assert(io.open(json_path, "w"))
    out:write(body)
    out:close()
    written = written + 1
  end

  ::continue::
end

if #failures > 0 then
  io.stderr:write("tutor sidecars FAILED\n")
  for _, f in ipairs(failures) do io.stderr:write("  " .. f .. "\n") end
  vim.cmd("cquit 1")
end

print(check
  and ("tutor sidecars: %d lesson(s) up to date"):format(checked)
  or  ("tutor sidecars: wrote %d lesson(s)"):format(written))
