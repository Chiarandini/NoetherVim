-- NoetherVim web search utilities
-- Commands: :Search, :SearchWith, :Wikipedia, :StackOverflow, :YouTube, :SetSearchEngine
-- Lua API:  M.search_diagnostic_under_cursor(), M.search_selected_text(), M.open_plugin_repo()

local M = {}

local search_engines = {
  duckduckgo   = "https://duckduckgo.com/?q=%s",
  brave        = "https://search.brave.com/search?q=%s&source=web",
  ecosia       = "https://www.ecosia.org/search?method=index&q=%s",
  google       = "https://www.google.com/search?q=%s",
  github       = "https://github.com/search?q=%s&type=repositories",
  startpage    = "https://www.startpage.com/do/dsearch?query=%s",
  reddit       = "https://www.reddit.com/search/?q=%s",
  stackoverflow= "https://stackoverflow.com/search?q=%s",
  wikipedia    = "https://www.wikipedia.org/search-redirect.php?language=en&go=Go&search=%s",
  youtube      = "https://www.youtube.com/results?search_query=%s",
}

local current_engine = "brave"

local function open_url(url)
  vim.ui.open(url)
end

local function encode(query)
  return query:gsub("[^%w%-_.~]", function(c)
    return c == " " and "%20" or string.format("%%%02X", string.byte(c))
  end)
end

local function web_search(query, engine)
  if not query or query == "" then
    vim.notify("Empty query.", vim.log.levels.WARN, { title = "Web Search" })
    return
  end
  local url = search_engines[engine or current_engine]
  if not url then
    vim.notify("Unknown engine: " .. (engine or current_engine), vim.log.levels.ERROR,
      { title = "Web Search" })
    return
  end
  open_url(url:format(encode(query)))
end

-- ──────────────────────────────────────────────────────────────
--  Commands
-- ──────────────────────────────────────────────────────────────

local function engine_complete(_, line, _)
  local args    = vim.split(line, "%s+")
  local partial = #args == 2 and (args[2] or "") or ""
  local matches = {}
  for e in pairs(search_engines) do
    if e:find(partial) == 1 then table.insert(matches, e) end
  end
  return matches
end

vim.api.nvim_create_user_command("Search", function(o)
  local q = table.concat(o.fargs, " ")
  vim.notify("Searching: " .. q, vim.log.levels.INFO, { title = "Web Search" })
  web_search(q)
end, { nargs = "+", desc = "search the web" })

vim.api.nvim_create_user_command("Wikipedia", function(o)
  local q = table.concat(o.fargs, " ")
  vim.notify("Wikipedia: " .. q, vim.log.levels.INFO, { title = "Web Search" })
  web_search(q, "wikipedia")
end, { nargs = "+", desc = "search Wikipedia" })

vim.api.nvim_create_user_command("StackOverflow", function(o)
  local q = table.concat(o.fargs, " ")
  web_search(q, "stackoverflow")
end, { nargs = "+", desc = "search StackOverflow" })

vim.api.nvim_create_user_command("YouTube", function(o)
  local q = table.concat(o.fargs, " ")
  web_search(q, "youtube")
end, { nargs = "+", desc = "search YouTube" })

vim.api.nvim_create_user_command("SearchWith", function(opts)
  local engine = opts.fargs[1]
  local q      = table.concat(vim.list_slice(opts.fargs, 2), " ")
  if not search_engines[engine] then
    vim.notify("Unknown engine: " .. engine, vim.log.levels.ERROR, { title = "Web Search" })
    return
  end
  web_search(q, engine)
end, { nargs = "+", desc = "search with specific engine", complete = engine_complete })

vim.api.nvim_create_user_command("SetSearchEngine", function(o)
  local engine = o.fargs[1]
  if search_engines[engine] then
    current_engine = engine
    vim.notify("Engine: " .. engine, vim.log.levels.INFO, { title = "Search Engine" })
  else
    vim.notify("Unknown: " .. engine, vim.log.levels.ERROR, { title = "Search Engine" })
  end
end, { nargs = 1, desc = "set default search engine", complete = engine_complete })

-- ──────────────────────────────────────────────────────────────
--  Lua API
-- ──────────────────────────────────────────────────────────────

function M.search_diagnostic_under_cursor()
  local diags = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
  if #diags == 0 then
    vim.notify("No diagnostic under cursor", vim.log.levels.INFO, { title = "Web Search" })
    return
  end
  local q = diags[1].message .. " " .. (vim.bo.filetype ~= "" and vim.bo.filetype or vim.fn.expand("%:e"))
  web_search(q)
end

function M.search_selected_text()
  vim.cmd('silent normal! "xy')
  local text = vim.fn.getreg("x")
  if text == "" then
    vim.notify("No text selected", vim.log.levels.WARN, { title = "Web Search" })
    return
  end
  web_search(text:gsub("[\n\t]+", " "):gsub("%s+", " "))
end

function M.open_plugin_repo()
  local word = vim.fn.expand("<cWORD>")
  local repo = word:match("([^\"\\s]+/[^\"\\s]+)")
  if repo then
    open_url("https://github.com/" .. repo)
  else
    vim.notify("Not a GitHub repo name", vim.log.levels.WARN, { title = "Plugin Repo" })
  end
end

return M
