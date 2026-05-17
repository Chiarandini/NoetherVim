-- for code running
return{ 'CRAG666/code_runner.nvim',
keys = {
	{'<leader>RR', '<cmd>RunCode<CR>', { noremap = true, silent = false, desc = 'run code' }},
	-- {'<F5>', '<cmd>RunCode<CR>', { noremap = true, silent = false, desc = 'run code' }},
},
config = function()
	require("code_runner").setup({
		mode = 'float',
		float = { border = "double" },
		filetype = {
			java = { "cd $dir &&", "javac $fileName &&", "java $fileNameWithoutExt" },
			python = "python3 -u",
			typescript = "deno run",
			rust = { "cd $dir &&", "rustc $fileName &&", "$dir/$fileNameWithoutExt" },
		},
	})
	vim.keymap.set("n", "<leader>RT", function()
		local ok, bt = pcall(require, "betterTerm")
		if not ok then
			vim.notify("betterTerm not available (enable noethervim.suites.better-term)", vim.log.levels.WARN)
			return
		end
		bt.send(require("code_runner.commands").get_filetype_command(), 1, { clean = false, interrupt = true })
	end, { desc = "Run in terminal (betterTerm)" })
end
}
