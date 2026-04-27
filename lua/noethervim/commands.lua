-- NoetherVim user-facing commands and their associated keymaps

-- ──────────────────────────────────────────────────────────────
--  Reset  -- close all buffers and show a clean dashboard
-- ──────────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("Reset", function(opts)
  local bufs = vim.api.nvim_list_bufs()
  if not opts.bang then
    for _, buf in ipairs(bufs) do
      if vim.api.nvim_get_option_value("modified", { buf = buf }) then
        vim.notify("Unsaved changes. Use :Reset! to force.", vim.log.levels.ERROR)
        return
      end
    end
  end
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = opts.bang })
    end
  end
  -- Try Snacks dashboard first, then Alpha as fallback
  if not pcall(function() require("snacks").dashboard() end) then
    pcall(vim.cmd, "Alpha")
  end
end, {
  bang = true,
  desc = "close all buffers and open dashboard",
})

-- ──────────────────────────────────────────────────────────────
--  DiffOrig  -- diff the current buffer against its on-disk version
-- ──────────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("DiffOrig", function()
  local ft = vim.bo.filetype
  vim.cmd("vert new")
  vim.bo.buftype   = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.filetype  = ft
  vim.cmd("r ++edit #")
  vim.cmd("0d_")
  vim.cmd("diffthis")
  vim.cmd("wincmd p")
  vim.cmd("diffthis")
end, { desc = "diff buffer against on-disk file" })

-- ──────────────────────────────────────────────────────────────
--  Redir  -- redirect :command / !shell output to scratch buffer
-- ──────────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("Redir", function(opts)
  local cmd = opts.args
  local output
  if cmd:sub(1, 1) == "!" then
    output = vim.fn.system(cmd:sub(2))
  else
    output = vim.api.nvim_exec2(cmd, { output = true }).output
  end
  vim.cmd("tabnew")
  vim.bo.buflisted = false
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  local lines = vim.split(output or "", "\n")
  table.insert(lines, 1, cmd)
  table.insert(lines, 2, "----")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end, { nargs = 1, desc = "redirect command output to scratch buffer" })

-- ──────────────────────────────────────────────────────────────
--  switch_case  -- toggle camelCase ↔ snake_case under cursor
-- ──────────────────────────────────────────────────────────────

local function switch_case()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  local word       = vim.fn.expand("<cword>")
  local word_start = vim.fn.matchstrpos(vim.fn.getline("."), "\\k*\\%" .. (col + 1) .. "c\\k*")[2]

  if word:find("[a-z][A-Z]") then
    local snake = word:gsub("([a-z])([A-Z])", "%1_%2"):lower()
    vim.api.nvim_buf_set_text(0, line - 1, word_start, line - 1, word_start + #word, { snake })
  elseif word:find("_[a-z]") then
    local camel = word:gsub("(_)([a-z])", function(_, l) return l:upper() end)
    vim.api.nvim_buf_set_text(0, line - 1, word_start, line - 1, word_start + #word, { camel })
  else
    vim.notify("Not camelCase or snake_case", vim.log.levels.WARN)
  end
end

vim.keymap.set("n", "<leader>s", switch_case, { desc = "toggle camelCase/snake_case" })

-- ──────────────────────────────────────────────────────────────
--  show_modified_buffers  -- list unsaved buffers in quickfix
-- ──────────────────────────────────────────────────────────────

local function show_modified_buffers()
  local items = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf)
      and vim.api.nvim_get_option_value("modified", { buf = buf })
    then
      local name = vim.api.nvim_buf_get_name(buf)
      table.insert(items, {
        bufnr    = buf,
        filename = name ~= "" and name or "[No Name]",
        lnum     = 1,
        col      = 0,
        text     = name ~= "" and name or "[No Name]",
      })
    end
  end
  if #items > 0 then
    vim.fn.setqflist({}, " ", { title = "Modified Buffers", items = items })
    vim.cmd("copen")
  else
    vim.notify("No modified buffers.", vim.log.levels.INFO)
  end
end

vim.keymap.set("n", "<c-w>u", show_modified_buffers, { noremap = true, silent = true,
  desc = "show unsaved buffers in quickfix" })

-- ──────────────────────────────────────────────────────────────
--  Web search command (:Search [<engine>|set] <query>)
-- ──────────────────────────────────────────────────────────────

require("noethervim.util.web_search")

-- string:replace was removed -- use require("noethervim.util").str_replace() instead.
