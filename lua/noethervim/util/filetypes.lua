--- Filetype lists the distro keys behaviour off. `profiles.classes` in
--- `lua/user/config.lua` reclassifies a filetype (read by profiles/init.lua);
--- `q_close` there adds to or removes from the `q` list, folded in below
--- once at load time.

local M = {}

M.writing = {
  tex = true, markdown = true, norg = true, text = true,
  gitcommit = true, gitsendemail = true, mail = true,
  rst = true, typst = true,
}

M.non_code = {
  json = true, jsonc = true, yaml = true, toml = true,
  help = true, man = true, lspinfo = true, query = true,
  qf = true, oil = true, terminal = true, tutor = true,
  snacks_dashboard = true, snacks_picker_input = true,
  snacks_layout_box = true, snacks_notif = true,
  snacks_terminal = true,
  ["noethervim-notification"] = true,
  lazy = true, mason = true, checkhealth = true,
  notify = true, TelescopePrompt = true,
  Trouble = true, trouble = true,
  ["dap-repl"] = true, ["dap-float"] = true,
  dapui_scopes = true, dapui_breakpoints = true,
  dapui_stacks = true, dapui_watches = true, dapui_console = true,
}

--- Filetypes where a bare `q` closes the window. A list rather than a set,
--- because it is handed straight to an autocmd `pattern`.
---
--- Editable filetypes are deliberately absent: `q` would shadow macro
--- recording in a buffer you might actually type into. `qf` is handled by
--- ftplugin/qf.lua instead.
M.q_close = {
  "help", "man", "lspinfo", "checkhealth",
  "notify", "fugitiveblame",
  "startuptime", "lazy", "mason",
  "spectre_panel", "crunner", "dap-float",
  "DressingInput", "cmp_menu",
  "typr", "snacks_notif", "snacks_terminal",
  "nvim-undotree", "undotree", "diff",
  "noethervim-notification",
  "dapui_scopes", "dapui_stacks", "dapui_breakpoints", "dapui_console",
  "dapui_watches", "dap-repl",
  "neotest-summary", "neotest-output", "neotest-output-panel",
  "neotest-attach",
}

do
  local q_close = require("noethervim.config").get().q_close
  if type(q_close) == "table" then
    local kept = {}
    for _, ft in ipairs(M.q_close) do
      if q_close[ft] ~= false then kept[#kept + 1] = ft end
    end
    for ft, on in pairs(q_close) do
      if on == true and not vim.tbl_contains(kept, ft) then kept[#kept + 1] = ft end
    end
    M.q_close = kept
  end
end

return M
