local broil = {}

local config = require("broil.config")
local ui = require("broil.ui")
local utils = require("broil.utils")

broil.setup = function(opts)
	config.set(opts)

	-- highlights
	vim.api.nvim_command("highlight BroilPreviewMessageFillchar guifg=#585b70")
	vim.api.nvim_command("highlight BroilPreviewMessage guifg=#b4befe")
	vim.api.nvim_command("highlight BroilDeleted guifg=#f38ba8")
	vim.api.nvim_command("highlight BroilEdited guifg=#f9e2af")
	vim.api.nvim_command("highlight BroilAdded guifg=#a6e3a1")
	vim.api.nvim_command("highlight BroilCopy guifg=#89dceb")
	vim.api.nvim_command("highlight BroilSearchTerm guifg=#f9e2af")
	vim.api.nvim_command("highlight BroilDirLine guifg=#89b4fa")
	vim.api.nvim_command("highlight BroilPruningLine guifg=#a6adc8")
	vim.api.nvim_command("highlight BroilRelativeLine guifg=#74c7ec")
	vim.api.nvim_command("highlight BroilHelpCommand guifg=#b4befe")
	vim.api.nvim_command("highlight BroilEditorHeadline guifg=#cba6f7")
	vim.api.nvim_command("highlight BroilQueued guifg=#94e2d5")
	vim.api.nvim_command("highlight BroilInfo guifg=#b4befe")
	vim.api.nvim_command("highlight BroilInactive guifg=#a6adc8")
	vim.api.nvim_command("highlight BroilActive guifg=#f2cdcd")
	vim.api.nvim_command("highlight BroilSearchIcon guifg=#bac2de")

	-- netrw integration
	vim.api.nvim_create_user_command("BroilToggleNetrw", function(opts)
		local path = opts.args -- Get the path argument
		local netrw_bufs = {}
		local bufs = vim.api.nvim_list_bufs()
		for _, buf in ipairs(bufs) do
			if vim.bo[buf].filetype == "netrw" then
				table.insert(netrw_bufs, buf)
			end
		end
		if #netrw_bufs > 0 then
			for _, buf in ipairs(netrw_bufs) do
				vim.cmd("bdelete! " .. buf)
			end
		else
			if path ~= "" then
				vim.cmd("Hexplore " .. path)
			else
				vim.cmd("Hexplore")
			end
		end
	end, { nargs = "?" })

	-- run custom function on c-t in netrw
	vim.api.nvim_create_augroup("netrw", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = "netrw",
		pattern = "netrw",
		callback = function()
			vim.keymap.set("n", config.mappings.open_in_netrw, function()
				broil.open(vim.b.netrw_curdir)
				vim.cmd("BroilToggleNetrw")
			end, { noremap = true, silent = true, buffer = true })
		end,
	})
end

broil.open = function(path)
	if path then
		-- Remove trailing slash if it exists
		ui.open_path = path:gsub("/$", "")
	else
		ui.open_path = utils.get_path_of_current_window_or_nvim_cwd()
	end
	ui.open()
end

return broil
