-- templates.lua -- enumerate the files in templates/ and write them into
-- the user's config dir with diff confirmation. Pairs with the
-- :NoetherVim templates picker.

---@diagnostic disable: undefined-doc-name

local Snacks = require("snacks")
local ui = require("noethervim.inspect.ui")
local effective_root = ui.effective_root
local confirm_readonly = ui.confirm_readonly
local hint_footer = ui.hint_footer

local M = {}

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

local function file_exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

---Recursive scan of `dir`, returning every file relative to it.
---@param dir string  absolute root
---@return string[]   paths relative to dir, with forward slashes
local function walk(dir)
  local out = {}
  local function visit(rel)
    local abs = rel == "" and dir or (dir .. "/" .. rel)
    local handle = vim.uv.fs_scandir(abs)
    if not handle then return end
    while true do
      local name, ftype = vim.uv.fs_scandir_next(handle)
      if not name then break end
      local sub = rel == "" and name or (rel .. "/" .. name)
      if ftype == "directory" then
        visit(sub)
      elseif ftype == "file" or ftype == "link" then
        out[#out + 1] = sub
      end
    end
  end
  visit("")
  return out
end

---Pick a one-line description from the first informational comment in a
---template. Skips separator lines (`-- ──...`) and blank lines.
local function extract_description(content)
  for line in content:gmatch("([^\n]*)\n?") do
    local body = line:match("^%-%-%s*(.+)$")
    if body and not body:match("^[─-]+$") and not body:match("^%s*$") then
      return body
    end
    -- Stop at the first non-comment, non-blank line so we don't scan the
    -- entire file.
    if line ~= "" and not line:match("^%s*%-%-") then break end
  end
  return ""
end

---Translate a path under templates/ to the matching destination under
---<config>/lua/. Drops the `.example` suffix from the filename.
---  templates/user/options.example.lua  ->  user/options.lua
---  templates/user/plugins/example.lua   ->  user/plugins/example.lua
local function dest_relative(rel)
  return (rel:gsub("%.example%.lua$", ".lua"))
end

---List every template under `<root>/templates/`, with metadata.
---@param root string  NoetherVim install (or dev) root
---@return { name: string, rel: string, src: string, dest: string, exists: boolean, desc: string }[]
function M.list(root)
  if not root then return {} end
  local templates_dir = root .. "/templates"
  if not file_exists(templates_dir) then return {} end
  local config_lua = vim.fn.stdpath("config") .. "/lua"

  local items = {}
  for _, rel in ipairs(walk(templates_dir)) do
    if rel:match("%.lua$") then
      local src       = templates_dir .. "/" .. rel
      local dest_rel  = dest_relative(rel)
      local dest      = config_lua .. "/" .. dest_rel
      local content   = read_file(src) or ""
      local desc      = extract_description(content)
      local name      = vim.fn.fnamemodify(dest_rel, ":t:r") -- bare basename
      items[#items + 1] = {
        name   = name,
        rel    = dest_rel,
        src    = src,
        dest   = dest,
        exists = file_exists(dest),
        desc   = desc,
      }
    end
  end
  table.sort(items, function(a, b) return a.rel < b.rel end)
  return items
end

---Write `src` -> `dest`, gated by a unified-diff confirmation. Creates
---the parent directory if missing. Notifies on completion.
---@param src  string
---@param dest string
function M.write(src, dest)
  local template, terr = read_file(src)
  if not template then
    return vim.notify("NoetherVim: " .. terr, vim.log.levels.ERROR)
  end

  local current = ""
  if file_exists(dest) then
    current = read_file(dest) or ""
  end

  if current == template then
    vim.notify(("NoetherVim: %s already matches the template -- nothing to do"):format(dest), vim.log.levels.INFO)
    return
  end

  local body = vim.diff(current, template, { result_type = "unified", ctxlen = 3 })
  local diff = ("--- %s\n+++ %s (template)\n%s"):format(dest, src, body or "")

  local action = file_exists(dest) and "Overwrite" or "Create"
  require("noethervim.inspect.diff_modal").confirm({
    title   = ("%s %s"):format(action, vim.fn.fnamemodify(dest, ":~")),
    diff    = diff,
    on_done = function(accepted)
      if not accepted then
        vim.notify("NoetherVim: template write cancelled", vim.log.levels.INFO)
        return
      end
      vim.fn.mkdir(vim.fn.fnamemodify(dest, ":h"), "p")
      local ok, werr = write_file(dest, template)
      if not ok then
        return vim.notify("NoetherVim: " .. werr, vim.log.levels.ERROR)
      end
      vim.notify(("NoetherVim: wrote %s"):format(vim.fn.fnamemodify(dest, ":~")), vim.log.levels.INFO)

      -- Open what was just written. The point of writing a template out is to
      -- edit it, and closing the confirmation returns to whatever was on
      -- screen before -- the dashboard, most often, since this is a first-run
      -- step. Scheduled so the modal's window has finished closing.
      vim.schedule(function()
        vim.cmd("edit " .. vim.fn.fnameescape(dest))
      end)
    end,
  })
end

--- The template picker; <C-y> writes one into lua/user/.
function M.open()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end

  local templates = M
  local items = templates.list(root)
  if #items == 0 then
    return vim.notify("NoetherVim: no templates found under templates/", vim.log.levels.WARN)
  end

  local picker_items = {}
  for _, t in ipairs(items) do
    picker_items[#picker_items + 1] = {
      text     = t.rel .. " " .. t.desc .. (t.exists and " exists" or ""),
      file     = t.src,
      rel      = t.rel,
      src      = t.src,
      dest     = t.dest,
      exists   = t.exists,
      desc     = t.desc,
    }
  end

  Snacks.picker({
    title   = "NoetherVim Templates",
    items   = picker_items,
    preview = "file",
    confirm = confirm_readonly,
    format  = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      if item.exists then
        ret[#ret + 1] = { "[exists] ", "DiagnosticHint" }
      else
        ret[#ret + 1] = { "[new]    ", "DiagnosticOk" }
      end
      ret[#ret + 1] = { string.format("%-32s", item.rel) }
      ret[#ret + 1] = { item.desc, "Comment" }
      return ret
    end,
    actions = {
      write_template = function(picker)
        local item = picker:current()
        if not item or not item.src or not item.dest then return end
        picker:close()
        M.write(item.src, item.dest)
      end,
    },
    win = {
      input = {
        footer     = hint_footer({ { "<cr>", "open" }, { "<c-y>", "write" } }),
        footer_pos = "center",
        keys = {
          ["<CR>"]  = { "confirm",        mode = { "i", "n" }, desc = "open template (readonly)" },
          ["<C-y>"] = { "write_template", mode = { "i", "n" }, desc = "write template into lua/user/" },
        },
      },
      list = {
        keys = {
          ["<CR>"]  = { "confirm",        desc = "open template (readonly)" },
          ["<C-y>"] = { "write_template", desc = "write template into lua/user/" },
        },
      },
    },
  })
end

return M
