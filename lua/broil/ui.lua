local Tree_Builder = require("broil.tree_builder")
local Tree = require("broil.tree")
local utils = require("broil.utils")
local Path = require("plenary.path")
local config = require("broil.config")
local async = require("plenary.async")
local keymap = require("broil.keymap")

local ui = {
	-- #State
	mode = "tree", -- tree or buffer
	-- #Tree Content
	open_path = nil,
	open_dir = nil,
	open_history = {}, -- we can reset to this later
	buf_id = nil,
	win_id = nil,
	tree = nil,
	tree_win = {
		height = math.ceil(vim.o.lines * 0.6) - 1, -- 60% height
	},
	original_win_id = nil,
	-- #Search
	search_win_id = nil,
	search_term = "", -- current search filter,
	search_ns_id = vim.api.nvim_create_namespace("BroilSearchIcon"),
	-- #Info Bar
	info_buf_id = nil,
	info_highlight_ns_id = vim.api.nvim_create_namespace("BroilInfoHighlights"),
	-- #Preview
	preview_buf_id = nil,
	preview_win_id = nil,
	preview_tree = nil,
	-- #Tree Edits
	spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
	spinner_frame = 1,
	spinner_timer = nil,
}

--- scan the file system at dir and create a tree view for the buffer
ui.create_tree_window = function()
	-- 1. create a tree buffer
	ui.buf_id = vim.api.nvim_create_buf(false, true)
	vim.cmd([[
  function! BroilFoldText()
    let line = getline(v:foldstart)
    let lines = v:foldend - v:foldstart + 1
    return line . " ..." . lines . " unlisted"
  endfunction
  ]])
	vim.api.nvim_set_option_value("modifiable", true, { buf = ui.buf_id })
	vim.api.nvim_set_option_value("cursorline", true, { win = ui.win_id })

	vim.api.nvim_set_option_value("signcolumn", "yes", { win = ui.win_id })
	vim.api.nvim_set_option_value("foldtext", "BroilFoldText()", { win = ui.win_id })
	vim.api.nvim_set_option_value("foldmethod", "manual", { win = ui.win_id })

	-- 2. create a new tree buffer window
	if ui.win_id ~= nil then
		vim.api.nvim_win_close(ui.win_id, true)
	end

	-- Create a split window with a specific height
	vim.api.nvim_command("aboveleft " .. ui.tree_win.height .. "split")
	ui.win_id = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(ui.win_id, ui.buf_id)
	vim.wo[ui.win_id].conceallevel = 3
end

ui.create_search_window = function()
	-- Create a buffer for the search window
	ui.search_buf_id = vim.api.nvim_create_buf(false, true)

	-- If a search window already exists, close it
	if ui.search_win_id ~= nil then
		vim.api.nvim_win_close(ui.search_win_id, true)
	end

	-- Create a split window with a specific height for the search window
	vim.api.nvim_command("botright " .. 1 .. "split")
	ui.search_win_id = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(ui.search_win_id, ui.search_buf_id)
	vim.api.nvim_set_option_value("winfixheight", true, { win = ui.search_win_id })

	-- Start insert mode in the new search window
	vim.api.nvim_command("startinsert")

	-- Set the initial search term
	ui.set_search("")
	vim.api.nvim_command("setlocal nonumber")
	vim.api.nvim_command("setlocal norelativenumber")
	vim.api.nvim_command("setlocal buftype=prompt")
	vim.fn.prompt_setprompt(ui.search_buf_id, '')
end

--- create the info bar at the top
ui.create_info_bar_window = function()
	ui.info_buf_id = vim.api.nvim_create_buf(false, true)

	-- If a info bar window already exists, close it
	if ui.info_win_id ~= nil then
		vim.api.nvim_win_close(ui.info_win_id, true)
	end

	local opts = {
		style = "minimal",
		relative = "win",
		win = ui.win_id,
		width = vim.o.columns,
		height = 1,
		row = vim.api.nvim_win_get_height(ui.win_id),
		col = 0,
	}

	ui.set_info_bar_message()
	ui.info_win_id = vim.api.nvim_open_win(ui.info_buf_id, false, opts)
end

ui.create_preview_window = function()
	ui.preview_buf_id = vim.api.nvim_create_buf(false, true)

	-- If a preview window already exists, close it
	if ui.preview_win_id ~= nil then
		vim.api.nvim_win_close(ui.preview_win_id, true)
	end

	-- Create a split window for the preview window
	local split_width = math.floor(vim.api.nvim_win_get_width(ui.win_id) / 2.5)
	vim.api.nvim_command(split_width .. "vsplit")
	ui.preview_win_id = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(ui.preview_win_id, ui.preview_buf_id)

	vim.api.nvim_set_option_value("modifiable", false, { buf = ui.preview_buf_id })

	-- set the content of the preview window to the hovered node
	vim.api.nvim_create_autocmd({ "CursorMoved" }, {
		buffer = ui.buf_id,
		callback = function()
			ui.preview_hovered_node(false)
		end,
	})
end

--- @param bool preview_full_file_or_dir only preview the full file or dir if we actually entered the preview window.
--- Otherwise its enough to display as many lines as we can fit in the preview window
ui.preview_hovered_node = function(preview_full_file_or_dir)
	utils.debounce("preview", function()
		if not ui.win_id then
			return
		end
		local cursor_pos = vim.api.nvim_win_get_cursor(ui.win_id)
		local cursor_y = cursor_pos[1]
		local cursor_line = vim.api.nvim_buf_get_lines(ui.buf_id, cursor_y - 1, cursor_y, false)[1]
		local path_id = utils.get_bid_by_match(cursor_line)
		local bline = ui.tree:find_by_id(path_id)

		if not bline then
			return
		end

		if bline.file_type == "directory" then
			local render_async = async.void(function()
				local builder = Tree_Builder:new(bline.path, {
					pattern = "",
					optimal_lines = ui.tree_win.height,
					maximum_search_time_sec = 0,
				})
				local tree_build = builder:build_tree()
				ui.prev_tree = Tree:new({
					pattern = "",
					buf_id = ui.preview_buf_id,
					win_id = ui.preview_win_id,
					lines = tree_build.lines,
					highest_score_index = tree_build.highest_score_index,
					open_path_index = tree_build.open_path_index,
				})

				vim.api.nvim_set_option_value("modifiable", true, { buf = ui.preview_buf_id })
				ui.prev_tree:render()

				local current_lines = vim.api.nvim_buf_get_lines(ui.prev_tree.buf_id, 0, -1, false)
				for index, line in ipairs(current_lines) do
					ui.prev_tree:draw_line_extmarks(index, line, current_lines)
				end

				vim.api.nvim_set_option_value("modifiable", false, { buf = ui.preview_buf_id })

				ui.prev_tree:initial_selection()
				builder:destroy()
				vim.api.nvim_set_option_value("filetype", nil, { buf = ui.preview_buf_id })
			end)
			async.run(render_async)
		else
			-- check if file is too large to preview
			local mb_filesize = utils.bytes_to_megabytes(bline.fs_stat.size)
			if mb_filesize > config.file_size_preview_limit_mb then
				vim.api.nvim_set_option_value("modifiable", true, { buf = ui.preview_buf_id })
				vim.api.nvim_buf_set_lines(
					ui.preview_buf_id,
					0,
					-1,
					false,
					{ "File size limit of " .. config.file_size_preview_limit_mb .. "mb exceeded." }
				)
				vim.api.nvim_set_option_value("modifiable", false, { buf = ui.preview_buf_id })
				return
			end

			if utils.check_is_binary(bline.path) then
				utils.set_preview_message(ui.preview_buf_id, ui.preview_win_id, "Binary file")
				return
			end

			Path:new(bline.path):_read_async(vim.schedule_wrap(function(data)
				vim.api.nvim_set_option_value("modifiable", true, { buf = ui.preview_buf_id })
				pcall(vim.api.nvim_buf_set_lines, ui.preview_buf_id, 0, -1, false, vim.split(data, "[\r]?\n"))
				vim.api.nvim_set_option_value("modifiable", false, { buf = ui.preview_buf_id })
				--
				local detect_filetype = vim.filetype.match({ buf = ui.preview_buf_id, filename = bline.name })
				pcall(vim.api.nvim_set_option_value, "filetype", detect_filetype, { buf = ui.preview_buf_id })
				if config.search_mode == 1 and #bline.grep_results > 0 then
					local first_result = bline.grep_results[1]
					pcall(vim.api.nvim_win_set_cursor, ui.preview_win_id, { first_result.row, first_result.column })
					vim.api.nvim_buf_add_highlight(
						ui.preview_buf_id,
						ui.search_ns_id,
						"BroilSearchTerm",
						first_result.row - 1,
						first_result.column - 2,
						first_result.column_end
					)
				end
			end))
		end
	end, config.preview_debounce)()
end

--- @param msg string|nil
--- @param type 'verb'|'search'|nil
--- highlights everything in '' quotes
ui.set_info_bar_message = function(msg, type)
	if (not ui.info_win_id) then
		return
	end

	if not msg then
		local time_str = ""
		if ui.render_start ~= nil and ui.render_end ~= nil then
			local time_diff = vim.fn.reltime(ui.render_start, ui.render_end)
			time_str = "  |'" .. vim.fn.reltimestr(time_diff):gsub(" ", "") .. "sec'"
		end

		local root_path = ""
		if ui.tree then
			root_path = "'" .. ui.tree.lines[1].path:gsub(vim.fn.getcwd(), "") .. "' | "
		end

		msg = root_path
				.. "Hit '"
				.. config.mappings.open_selected_node
				.. "|"
				.. config.mappings.open_selected_node2
				.. "' to open, '"
				.. config.mappings.select_prev_node
				.. "|"
				.. config.mappings.select_next_node
				.. "' to move, '(exact), ^(starts), (ends)$, !(not), | (or)'  or  ':<verb>' to execute a command."
				.. time_str
	end

	-- Set the buffer lines
	local icon = " 󰙎 "
	if type == "search" then
		icon = " " .. ui.spinner_frames[ui.spinner_frame] .. " "
		ui.spinner_frame = (ui.spinner_frame % #ui.spinner_frames) + 1
	end
	vim.api.nvim_buf_set_lines(ui.info_buf_id, 0, -1, false, { icon .. msg })

	-- Find and highlight each quoted string
	local start_pos = 1
	while true do
		-- Find the next quoted string
		local start_quote, end_quote = string.find(msg, "'[^']*'", start_pos)

		-- If no more quoted strings were found, break the loop
		if not start_quote then
			break
		end

		-- Adjust the positions for the prefix and the quotes themselves
		local highlight_start = start_quote + 6 -- 6 for ' 󰙎  ' and 1 for the quote
		local highlight_end = end_quote + 6 - 1 -- 6 for ' 󰙎  ' and -1 because the end position is inclusive

		-- Add the highlight
		vim.api.nvim_buf_add_highlight(ui.info_buf_id, -1, "BroilHelpCommand", 0, highlight_start, highlight_end)

		-- Move to the next position
		start_pos = end_quote + 1
	end
end

--- Attaches Event Listener that gets called when the search input is changed
ui.on_search_input_listener = function()
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = ui.search_buf_id,
		callback = function()
			local previous_search_term = ui.search_term
			local search_buf_text = vim.api.nvim_buf_get_lines(ui.search_buf_id, 0, -1, false)[1]

			-- split the search buf text at the first ':'colon
			local colon_pos = string.find(search_buf_text, ":")

			if colon_pos then
				ui.search_term = string.sub(search_buf_text, 1, colon_pos - 1)
			else
				ui.search_term = search_buf_text
			end

			if colon_pos then
				ui.set_verb(string.sub(search_buf_text, colon_pos + 1))
			else
				ui.set_verb()
			end

			if previous_search_term ~= ui.search_term then
				utils.debounce("search", function()
					ui.render()
				end, config.search_debounce)()
			end

			ui.set_search_input_sign_and_highlight()
		end,
	})
end

ui.set_search_input_sign_and_highlight = function()
	local search_buf_text = vim.api.nvim_buf_get_lines(ui.search_buf_id, 0, -1, false)[1]
	-- Set the extmark at the beginning of the buffer and styling
	vim.api.nvim_buf_clear_namespace(ui.search_buf_id, ui.search_ns_id, 0, -1)
	if ui.verb ~= nil then
		vim.api.nvim_buf_set_extmark(
			ui.search_buf_id,
			ui.search_ns_id,
			0,
			0,
			{ sign_text = "", sign_hl_group = "BroilSearchIcon" }
		)
		local find_start = string.find(search_buf_text, ":")
		vim.api.nvim_buf_add_highlight(ui.search_buf_id, ui.search_ns_id, "BroilInactive", 0, 0, find_start or 0)
	else
		if config.search_mode == 0 then
			vim.api.nvim_buf_set_extmark(
				ui.search_buf_id,
				ui.search_ns_id,
				0,
				0,
				{ sign_text = "󰥨", sign_hl_group = "BroilSearchIcon" }
			)
		else
			vim.api.nvim_buf_set_extmark(
				ui.search_buf_id,
				ui.search_ns_id,
				0,
				0,
				{ sign_text = "󰱼", sign_hl_group = "BroilSearchIcon" }
			)
		end
	end
end

--- Set the verb in the info bar
--- @param verb string|nil
ui.set_verb = function(verb)
	local replaced_verb_variables = verb
	if replaced_verb_variables == nil then
		ui.set_info_bar_message()
	elseif replaced_verb_variables == "" then
		ui.set_info_bar_message(
			"Type a "
			.. vim.o.shell
			..
			" command to execute. 󰋗 :['%<space>' = 'selection_path', '%n' = 'selection_name', '.<space>' = 'view_path'], Hit 'enter' to execute it",
			"verb"
		)
	elseif
			replaced_verb_variables:find("%% ")
			or replaced_verb_variables:find("%. ")
			or replaced_verb_variables:find("%%n")
	then
		local tree_cursor = vim.api.nvim_win_get_cursor(ui.win_id)
		local cursor_line = vim.api.nvim_buf_get_lines(ui.buf_id, tree_cursor[1] - 1, tree_cursor[1], false)[1]

		local path_id = utils.get_bid_by_match(cursor_line)
		local bline = ui.tree:find_by_id(path_id)
		local root_node = ui.tree.lines[1]
		local bline_path = bline and bline.path or ""
		local bline_name = bline and bline.name or ""

		if bline_path == "" then
			bline_path = root_node.path ..
					"/" ..
					cursor_line:gsub("^%s*", ""):gsub("%[%d+%]$", "") -- remove leading whitespace and pathid
		end

		if bline_name == "" then
			bline_name = cursor_line:gsub("^%s*", ""):gsub("%[%d+%]$", "") -- remove leading whitespace and pathid
		end

		replaced_verb_variables = replaced_verb_variables:gsub("%% ", bline_path)
		replaced_verb_variables = replaced_verb_variables:gsub("%. ", root_node.path)
		replaced_verb_variables = replaced_verb_variables:gsub("%%n ", bline_name)

		-- replace the verb path in the actual search buffer
		vim.api.nvim_buf_set_lines(ui.search_buf_id, 0, -1, false, { ui.search_term .. ":" .. replaced_verb_variables })
		vim.api.nvim_win_set_cursor(ui.search_win_id, { 1, #ui.search_term + #replaced_verb_variables + 2 })

		ui.set_info_bar_message(
			"Hit 'enter' to execute: " .. "'" .. replaced_verb_variables .. "' 󰋗 : ['%<space>', '%n', '.<space>']",
			"verb"
		)
	else
		ui.set_info_bar_message(
			"Hit 'enter' to execute: " .. "'" .. replaced_verb_variables .. "' 󰋗 : ['%<space>', '%n', '.<space>']",
			"verb"
		)
	end

	ui.verb = replaced_verb_variables
end

--- Display a help message
ui.help = function()
	print("broil help")
end

ui.select_next_node = function()
	if not ui.tree then
		return
	end
	ui.tree:select_next()
	ui.preview_hovered_node()
end

ui.select_prev_node = function()
	if not ui.tree then
		return
	end
	ui.tree:select_prev()
	ui.preview_hovered_node()
end

ui.scroll_up = function()
	if not ui.tree then
		return
	end

	ui.tree:scroll_up()
	ui.preview_hovered_node()
end

ui.scroll_down = function()
	if not ui.tree then
		return
	end

	ui.tree:scroll_down()
	ui.preview_hovered_node()
end

ui.scroll_top_node = function()
	if not ui.tree then
		return
	end

	ui.tree:scroll_top_node()
	ui.preview_hovered_node()
end

ui.scroll_end = function()
	if not ui.tree then
		return
	end

	ui.tree:scroll_end()
	ui.preview_hovered_node()
end

--- Opens the currently selected tree node (Tree.selected_render_index)
--- It enters the node if its a dir,
--- otherwise it opens the file in a new buffer
ui.open_selected_node_or_run_verb = function(just_open)
	-- if we have a verb, we execute it instead of opening the node
	if ui.verb ~= nil and ui.verb ~= "" and not just_open then
		return ui.run_current_verb()
	end

	local cursor_pos = vim.api.nvim_win_get_cursor(ui.win_id)
	local cursor_y = cursor_pos[1]

	if not ui.tree or cursor_y == 1 then
		return
	end

	local current_line = vim.api.nvim_buf_get_lines(ui.buf_id, cursor_y - 1, cursor_y, false)[1]
	local bid = utils.get_bid_by_match(current_line)
	local bline = ui.tree:find_by_id(bid)

	if not bline then
		return
	end

	if bline.file_type == "directory" then
		ui.open_path = bline.path
		ui.set_search("")
		ui.render()
	else
		ui.close()
		vim.api.nvim_command("edit " .. bline.path)
		vim.api.nvim_command("stopinsert")

		if config.search_mode == 1 and #bline.grep_results > 0 then
			local first_result = bline.grep_results[1]
			pcall(vim.api.nvim_win_set_cursor, 0, { first_result.row, first_result.column })
		end
	end
end

ui.run_current_verb = function()
	-- save the last hovered line to reselect after the next render
	local cursor_pos = vim.api.nvim_win_get_cursor(ui.win_id)
	local cursor_y = cursor_pos[1]
	local cursor_line = vim.api.nvim_buf_get_lines(ui.buf_id, cursor_y - 1, cursor_y, false)[1]
	local path_id = utils.get_bid_by_match(cursor_line)
	local bline = ui.tree:find_by_id(path_id)

	-- open split above ui.win_id
	-- create a floating terminal window
	local term_buf_id = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_open_win(term_buf_id, true, {
		relative = "win",
		width = vim.o.columns,
		height = vim.api.nvim_win_get_height(ui.win_id) + vim.api.nvim_win_get_height(ui.search_win_id) + 2,
		row = 0,
		col = 0,
		style = "minimal",
	})
	-- run the verb in the terminal
	vim.api.nvim_command("tcd " .. ui.open_dir)
	vim.api.nvim_command("term " .. ui.verb)

	-- rerender when the terminal is closed
	vim.api.nvim_create_autocmd({ "WinClosed" }, {
		buffer = term_buf_id,
		callback = function()
			ui.render(bline.id)
		end,
	})
end

--- Open the parent dir of the currently opened tree_view -> vim.fn.fnamemodify(Tree.root_path, ":h")
ui.open_parent_dir = function()
	if not ui.tree then
		return
	end

	local node = ui.tree.lines[1]

	if not node then
		return
	end

	local parent_dir = vim.fn.fnamemodify(node.path, ":h")

	if parent_dir then
		ui.open_path = parent_dir
		ui.render(node.id)
	end
end

--- open a floating window with a tree view of the current file's directory
ui.open = function()
	ui.original_win_id = vim.api.nvim_get_current_win()

	-- we are already open
	if ui.search_win_id and vim.api.nvim_win_is_valid(ui.search_win_id) then
		vim.api.nvim_set_current_win(ui.search_win_id)
		return
	end
	-- 1. create a search prompt at the bottom
	ui.create_search_window()
	ui.create_tree_window()
	ui.create_preview_window()
	ui.create_info_bar_window()

	-- focus the search window
	vim.api.nvim_set_current_win(ui.search_win_id)

	keymap.attach(ui)

	-- 4. attach event listeners
	ui.on_search_input_listener()
	ui.on_close_listener()

	ui.render()
end

ui.close = function()
	local function close_window_and_buffer(win_id)
		if win_id ~= nil then
			-- Get the buffer associated with the window
			local buf_id = vim.api.nvim_win_get_buf(win_id)
			-- Close the window first
			pcall(vim.api.nvim_win_close, win_id, true)
			-- Force close the buffer
			pcall(vim.api.nvim_buf_delete, buf_id, { force = true })
			return nil
		end
		return nil
	end

	-- Close windows and their associated buffers
	ui.win_id = close_window_and_buffer(ui.win_id)
	ui.search_win_id = close_window_and_buffer(ui.search_win_id)
	ui.info_win_id = close_window_and_buffer(ui.info_win_id)
	ui.preview_win_id = close_window_and_buffer(ui.preview_win_id)

	vim.api.nvim_command("stopinsert")

	-- try to reset to the window we originally opened from
	if ui.original_win_id then
		pcall(vim.api.nvim_set_current_win, ui.original_win_id)
	end
end

ui.on_close_listener = function()
	vim.api.nvim_create_autocmd({ "WinClosed" }, {
		buffer = ui.buf_id,
		callback = function()
			ui.close()
		end,
	})
	vim.api.nvim_create_autocmd({ "WinClosed" }, {
		buffer = ui.info_buf_id,
		callback = function()
			ui.close()
		end,
	})
	vim.api.nvim_create_autocmd({ "WinClosed" }, {
		buffer = ui.search_buf_id,
		callback = function()
			ui.close()
		end,
	})
	vim.api.nvim_create_autocmd({ "WinClosed" }, {
		buffer = ui.preview_buf_id,
		callback = function()
			ui.close()
		end,
	})

	vim.api.nvim_create_autocmd({ "WinClosed" }, {
		buffer = config.buf_id,
		callback = function()
			ui.close_config_float()
		end,
	})
end

ui.pop_history = function()
	if #ui.open_history > 1 then
		table.remove(ui.open_history, #ui.open_history)
		local path_before = ui.open_history[#ui.open_history]
		ui.open_path = path_before
		ui.render()
	end
end

ui.set_search = function(search_term)
	ui.search_term = search_term
	vim.api.nvim_buf_set_lines(ui.search_buf_id, 0, -1, false, { search_term })
end

ui.open_config_float = function()
	config:open_config_float(ui.win_id)
	ui.set_info_bar_message("Type: '<KEY>' to toggle setting. " ..
		config.mappings.close .. " or " .. config.mappings.open_config_float .. " to close.")
end

-- toggle the current tree_view to netrw (using config.netrw_command).
-- use the hovered line's directory first, fallback to the current open_dir
ui.open_in_netrw = function()
	local cursor_pos = vim.api.nvim_win_get_cursor(ui.win_id)
	local cursor_y = cursor_pos[1]

	if not ui.tree or cursor_y == 1 then
		ui.close()
		vim.api.nvim_command(config.netrw_command .. ui.open_dir)
		return
	end

	local current_line = vim.api.nvim_buf_get_lines(ui.buf_id, cursor_y - 1, cursor_y, false)[1]
	local bid = utils.get_bid_by_match(current_line)
	local bline = ui.tree:find_by_id(bid)

	if not bline then
		ui.close()
		vim.api.nvim_command(config.netrw_command .. ui.open_dir)
		return
	end

	if bline.file_type == "directory" then
		ui.close()
		vim.api.nvim_command(config.netrw_command .. bline.path)
	else
		ui.close()
		local file_dir = vim.fn.fnamemodify(bline.path, ":h")
		vim.api.nvim_command(config.netrw_command .. file_dir)
	end
end

ui.close_config_float = function()
	config:close_config_float()
	ui.set_info_bar_message()
	ui.set_search_input_sign_and_highlight()
	ui.render()
end

-- global ui.render metadata
local global_render_index = 0
local new_render_started = function(compare_render_index)
	return global_render_index > compare_render_index
end

--- @param selection_id number|nil node id to select after the render. If nil, select the highest score
ui.render = function(selection_id)
	if not ui.spinner_timer then
		ui.set_info_bar_message(nil, "search")
		ui.spinner_timer = vim.fn.timer_start(100, function()
			ui.set_info_bar_message(nil, "search")
		end, { ["repeat"] = -1 })
	end

	local render_async = async.void(function()
		-- keep track if another render started
		global_render_index = global_render_index + 1
		local current_render_index = global_render_index

		if ui.open_history[#ui.open_history] ~= ui.open_path then -- add the path to the history if its not the same
			table.insert(ui.open_history, ui.open_path)
		end

		if new_render_started(current_render_index) then
			return
		end

		local builder = Tree_Builder:new(ui.open_path, {
			pattern = ui.search_term,
			optimal_lines = ui.tree_win.height,
			maximum_search_time_sec = config.maximum_search_time_sec,
		})

		if new_render_started(current_render_index) then
			return
		end

		local tree_build = builder:build_tree()
		builder:destroy()
		if new_render_started(current_render_index) then
			return
		end

		ui.tree = Tree:new({
			pattern = ui.search_term,
			buf_id = ui.buf_id,
			win_id = ui.win_id,
			lines = tree_build.lines,
			highest_score_index = tree_build.highest_score_index,
			open_path_index = tree_build.open_path_index,
		})

		if new_render_started(current_render_index) then
			return
		end

		ui.tree:render()

		if new_render_started(current_render_index) then
			return
		end

		ui.tree:initial_selection(selection_id)

		if new_render_started(current_render_index) then
			return
		end

		local current_lines = vim.api.nvim_buf_get_lines(ui.tree.buf_id, 0, -1, false)

		for index, line in ipairs(current_lines) do
			ui.tree:draw_line_extmarks(index, line, current_lines)
		end

		if new_render_started(current_render_index) then
			return
		end

		ui.open_dir = builder.path
		ui.render_start = builder.build_start
		ui.render_end = builder.build_end
		ui.preview_hovered_node()

		utils.debounce("spinner", function()
			if ui.spinner_timer then
				vim.fn.timer_stop(ui.spinner_timer)
				ui.spinner_timer = nil
			end
			ui.set_info_bar_message()
		end, config.spinner_debounce)()
	end)

	async.run(render_async)
end

return ui
