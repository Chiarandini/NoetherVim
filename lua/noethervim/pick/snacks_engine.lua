--- The default picker engine: snacks' own sources for the six core verbs.
--- A snacks picker opened on any key counts as the last one served, so
--- `resume` reopens it.

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("noethervim.pick.snacks_engine", { clear = true }),
  pattern = "snacks_picker_input",
  callback = function() require("noethervim.pick").served("snacks") end,
})

---@param source string
local function open(source)
  return function(opts) require("snacks").picker[source](opts) end
end

return {
  files = open("files"),
  grep = open("grep"),
  grep_word = open("grep_word"),
  recent = function(opts) require("snacks").picker.recent({ title = opts.title }) end,
  buffers = function(opts) require("snacks").picker.buffers({ title = opts.title }) end,
  resume = function() require("snacks").picker.resume() end,
}
