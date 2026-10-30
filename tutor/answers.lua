-- Exercise answers for the NoetherVim lessons.
--
-- Each entry is { placeholder, expected }: the text shipped on the exercise
-- line, and the text that turns its ✗ into a ✓. `tools/gen-tutor-json.lua`
-- resolves the placeholder to a line number and writes the `.tutor.json`
-- sidecars, so no line number is ever typed by hand. Run it after editing any
-- lesson:
--
--   nvim --headless -l tools/gen-tutor-json.lua
--
-- A placeholder must appear exactly once in its lesson. Rewriting one without
-- updating it here is an error, not a silent miss.
--
-- An expected value of -1 accepts any edit, for exercises where the point is
-- to try something rather than to land on one answer.

return {
  ["noethervim-01-orientation"] = {
    { "I have read this far: no",
      "I have read this far: yes" },
    { "The health check is ___",
      "The health check is :checkhealth noethervim" },
    { "Every active keymap, grouped by prefix: ___",
      "Every active keymap, grouped by prefix: <Space>?" },
    { "The catalogue of things you can turn on: ___",
      "The catalogue of things you can turn on: <Space>cb" },
    { "The report that says whether anything is wrong: ___",
      "The report that says whether anything is wrong: :checkhealth noethervim" },
  },

  ["noethervim-02-namespaces"] = {
    { "this line is wrong",
      "this line is right" },
    { "The find-a-file picker is ___",
      "The find-a-file picker is <Space>ff" },
    { "The prefix that turns an option on is ___",
      "The prefix that turns an option on is [o" },
    { "Fuzzy-finding a file lives under: ___",
      "Fuzzy-finding a file lives under: <Space>" },
    { "Turning line numbers back on lives under: ___",
      "Turning line numbers back on lives under: [o" },
    { "Splitting the window lives under: ___",
      "Splitting the window lives under: <C-w>" },
    { "Closing this window and nothing else is: ___",
      "Closing this window and nothing else is: ZA" },
  },

  ["noethervim-03-files-and-windows"] = {
    { "The file browser opens with ___",
      "The file browser opens with <C-w><C-o>" },
    { "Inside any picker, the key list is ___",
      "Inside any picker, the key list is <F1>" },
    { "The editable directory browser: ___",
      "The editable directory browser: <C-w><C-o>" },
    { "Grep this directory for text: ___",
      "Grep this directory for text: <Space>gg" },
    { "Split the window vertically: ___",
      "Split the window vertically: <C-w>v" },
    { "List the keys the picker you are in binds: ___",
      "List the keys the picker you are in binds: <F1>" },
  },

  ["noethervim-04-profiles"] = {
    { "Wrap on, for this buffer: ___",
      "Wrap on, for this buffer: [ow" },
    { "The profile a markdown file gets: ___",
      "The profile a markdown file gets: writing" },
    { "The profile a python file gets: ___",
      "The profile a python file gets: code" },
    { "Turn wrapping off in this window: ___",
      "Turn wrapping off in this window: ]ow" },
    { "Fix the nearest misspelling, from insert mode: ___",
      "Fix the nearest misspelling, from insert mode: <C-l>" },
  },

  ["noethervim-05-your-config"] = {
    { "The template picker is ___",
      "The template picker is <Space>ct" },
    { "Start Neovim ignoring lua/user/ with ___=1 nvim",
      "Start Neovim ignoring lua/user/ with NOETHERVIM_NO_USER=1 nvim" },
    { "The directory your own configuration lives in: ___",
      "The directory your own configuration lives in: lua/user/" },
    { "The picker that writes a starting template: ___",
      "The picker that writes a starting template: <Space>ct" },
    { "The picker that shows whether your keymap override took: ___",
      "The picker that shows whether your keymap override took: <Space>ck" },
  },

  ["noethervim-06-bundles"] = {
    { "In the bundle picker, enable with ___",
      "In the bundle picker, enable with <C-y>" },
    { "The picker that lists every bundle: ___",
      "The picker that lists every bundle: <Space>cb" },
    { "The key that enables one: ___",
      "The key that enables one: <C-y>" },
    { "The window showing what lazy.nvim installed: ___",
      "The window showing what lazy.nvim installed: <C-w>ll" },
    { "The option key that merges rather than replaces: ___",
      "The option key that merges rather than replaces: opts" },
  },

  ["noethervim-07-lsp"] = {
    { "Go to the definition under the cursor: ___",
      "Go to the definition under the cursor: gd" },
    { "The multi-file diagnostics panel is ___",
      "The multi-file diagnostics panel is <C-w>Q" },
    { "Jump to where a symbol is defined: ___",
      "Jump to where a symbol is defined: gd" },
    { "Rename a symbol everywhere: ___",
      "Rename a symbol everywhere: <F2>" },
    { "Next diagnostic in this buffer: ___",
      "Next diagnostic in this buffer: ]d" },
    { "Format this buffer: ___",
      "Format this buffer: <Leader>ff" },
  },

  ["noethervim-08-terminal"] = {
    { "Toggle the terminal along the bottom: ___",
      "Toggle the terminal along the bottom: <C-w>t" },
    { "Next entry in the quickfix list: ___",
      "Next entry in the quickfix list: ]q" },
    { "Toggle the bottom terminal: ___",
      "Toggle the bottom terminal: <C-w>t" },
    { "Leave terminal mode and get the keys back: ___",
      "Leave terminal mode and get the keys back: <Esc><Esc>" },
    { "Run the file you are editing: ___",
      "Run the file you are editing: <Leader>rf" },
    { "Previous entry in the quickfix list: ___",
      "Previous entry in the quickfix list: [q" },
  },

  ["noethervim-09-git"] = {
    { "Next hunk in this buffer: ___",
      "Next hunk in this buffer: ]h" },
    { "Preview the hunk under the cursor: ___",
      "Preview the hunk under the cursor: <Leader>hp" },
    { "Stage the hunk under the cursor: ___",
      "Stage the hunk under the cursor: <Leader>hs" },
    { "Previous hunk in this buffer: ___",
      "Previous hunk in this buffer: [h" },
    { "The picker listing every changed file: ___",
      "The picker listing every changed file: <Space>Gs" },
  },

  ["noethervim-10-latex"] = {
    { "Compile this document: ___",
      "Compile this document: ,ll" },
    { "Jump to a label, through the tag stack: ___",
      "Jump to a label, through the tag stack: <C-]>" },
    { "Compile the document: ___",
      "Compile the document: ,ll" },
    { "View the PDF at the cursor: ___",
      "View the PDF at the cursor: ,lv" },
    { "Jump to the label under the cursor: ___",
      "Jump to the label under the cursor: <C-]>" },
    { "Come back from that jump: ___",
      "Come back from that jump: <C-t>" },
  },

  ["noethervim-11-snippets"] = {
    { "The config key for the Tab philosophy is ___",
      "The config key for the Tab philosophy is completion.style" },
    { "Stop all snippets, from insert mode: ___",
      "Stop all snippets, from insert mode: <C-u>" },
    { "Jump to the next placeholder: ___",
      "Jump to the next placeholder: <Tab>" },
    { "Jump back into the snippet under the cursor: ___",
      "Jump back into the snippet under the cursor: <Leader>j" },
    { "The picker listing every loaded snippet: ___",
      "The picker listing every loaded snippet: <Space>cs" },
    { "Open a snippet file for this filetype: ___",
      "Open a snippet file for this filetype: <Space>es" },
  },
}
