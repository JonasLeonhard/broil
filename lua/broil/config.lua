local Config = {
	mappings = {
		-- general
		help = "?",
		close = "<C-q>",
		pop_history = "<C-p>",
		open_config_float = "<C-c>",

		open_in_netrw = "<C-z>",

		-- search
		select_next_node = "<C-j>",
		select_next_node_normal = "j",
		select_prev_node = "<C-k>",
		select_prev_node_normal = "k",
		open_selected_node = "<CR>",
		open_selected_node2 = "<C-l>",
		open_parent_dir = "<C-h>",
	},
	special_paths = {
		[".DS_Store"] = "hide",
		[".astro"] = "no-enter",
		[".git"] = "no-enter",
		[".godot"] = "no-enter",
		[".next"] = "no-enter",
		[".svelte-kit"] = "no-enter",
		["build"] = "no-enter",
		["debug"] = "no-enter",
		["dist"] = "no-enter",
		["media"] = "no-enter",
		["node_modules"] = "no-enter",
		["release"] = "no-enter",
		["storybook-static"] = "no-enter",
		["target"] = "no-enter",
		["tmp"] = "no-enter",
		["vendor"] = "no-enter",
		[".zig-cache"] = "no-enter",
		["zig-out"] = "no-enter"
	},

	-- runtime configs
	search_mode = 0,                     -- 0 = 'fuzzy_find', 1 = 'grep'
	fzf_case_mode = 0,                   -- case_mode: number with 0 = smart_case, 1 = ignore_case, 2 = respect_case
	fzf_fuzzy_match = true,
	show_hidden = true,                  -- files/dirs with '.'
	show_special_paths_hide = false,     -- files/dirs with special_path == 'hide'
	enter_no_enter_special_paths = false, -- no-enter dirs with special_path == 'no-enter',
	sort_option = 0,                     -- 0 = 'Type',  1 = 'Size', 2 = 'Alphabetical', 3 = 'Children_count', 4 = 'Date_modified'
	sort_order = 0,                      -- 0 = 'Ascending', 1 = 'Descending'
	file_size_preview_limit_mb = 5,

	shell = vim.o.shell,

	-- switch to netrw command :netrw_command .. ui.open_dir
	netrw_command = "Hexplore ",

	-- internal config window
	buf_id = vim.api.nvim_create_buf(false, true),
	win_id = nil,
	config_window_ns_id = vim.api.nvim_create_namespace("BroilConfigWindow"),

	-- search
	maximum_search_time_sec = 0.5, -- when to stop gathering lines. Longer time might yield better and deeper matches at the cost of general speed
	search_debounce = 35,
	spinner_debounce = 200,
	preview_debounce = 50,
}

--- @param opts table|nil configuration See |broil.config|.
Config.set = function(opts)
	local new_conf = vim.tbl_deep_extend("keep", opts or {}, Config)
	for k, v in pairs(new_conf) do
		Config[k] = v
	end
end

function Config:open_config_float(win_id)
	if self.win_id then
		return vim.api.nvim_set_current_win(self.win_id)
	end
	vim.api.nvim_set_option_value("modifiable", false, { buf = self.buf_id })

	self:render_config_settings()

	local height = math.floor(vim.api.nvim_win_get_height(win_id) / 2)
	local opts = {
		style = "minimal",
		relative = "win",
		win = win_id,
		width = vim.o.columns,
		height = height,
		row = vim.api.nvim_win_get_height(win_id) - height,
		col = 0,
	}
	self.win_id = vim.api.nvim_open_win(self.buf_id, true, opts)

	vim.api.nvim_set_current_win(self.win_id)
	vim.api.nvim_command("stopinsert")
end

function Config:close_config_float()
	if self.win_id then
		vim.api.nvim_win_close(self.win_id, true)
		self.win_id = nil
	end
end

function Config:render_config_settings()
	vim.api.nvim_set_option_value("modifiable", true, { buf = self.buf_id })

	vim.api.nvim_buf_set_lines(self.buf_id, 0, -1, false, { "Toggle Settings:", "" })
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilEditorHeadline", 0, 0, 15)

	-- Search Mode:
	vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, { "-m: Search mode [fuzzy_find, content]" })
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInfo", 2, 0, 2)
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInactive", 2, 16, -1)
	if self.search_mode == 0 then
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 2, 17, 27)
	elseif self.search_mode == 1 then
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 2, 29, 36)
	end

	-- Sort:
	vim.api.nvim_buf_set_lines(
		self.buf_id,
		-1,
		-1,
		false,
		{ "-s: Sort by [file_type, size, alphabetical, children_count, date_modified]" }
	)
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInfo", 3, 0, 2)
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInactive", 3, 12, -1)
	if self.sort_option == 0 then
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 3, 13, 22)
	elseif self.sort_option == 1 then
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 3, 24, 28)
	elseif self.sort_option == 2 then
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 3, 30, 42)
	elseif self.sort_option == 3 then
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 3, 44, 58)
	elseif self.sort_option == 4 then
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 3, 60, 73)
	end

	-- Sort Order:
	vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, { "-o: Sort order [asc, desc]" })
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInfo", 4, 0, 2)
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInactive", 4, 12, -1)
	if self.sort_order == 0 then
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 4, 16, 19)
	else
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 4, 21, 25)
	end

	-- Show hidden:
	vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, { "-h: Show hidden [true, false]" })
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInfo", 5, 0, 2)
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInactive", 5, 16, -1)
	if self.show_hidden then
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 5, 17, 21)
	else
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 5, 23, 28)
	end

	-- Show special_paths with 'hide':
	vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, { '-H: Show special_paths with "hide" [true, false]' })
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInfo", 6, 0, 2)
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInactive", 6, 36, -1)
	if self.show_special_paths_hide then
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 6, 36, 40)
	else
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 6, 42, 47)
	end

	-- enter special_paths with 'no-enter':
	vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, { '-E: Enter special_paths with "no-enter" [true, false]' })
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInfo", 7, 0, 2)
	vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInactive", 7, 40, -1)
	if self.enter_no_enter_special_paths then
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 7, 41, 47)
	else
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 7, 47, 52)
	end

	-- Fuzzy case_mode
	if self.search_mode == 0 then
		vim.api.nvim_buf_set_lines(
			self.buf_id,
			-1,
			-1,
			false,
			{ "-C: Fuzzy case mode [smart_case, ignore_case, respect_case]" }
		)
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInfo", 8, 0, 2)
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInactive", 8, 20, -1)
		if self.fzf_case_mode == 0 then
			vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 8, 21, 31)
		elseif self.fzf_case_mode == 1 then
			vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 8, 33, 44)
		elseif self.fzf_case_mode == 2 then
			vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 8, 45, 58)
		end

		-- Fuzzy match
		vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, { "-F: Fuzzy search [true, false]" })
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInfo", 9, 0, 2)
		vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilInactive", 9, 17, -1)
		if self.fzf_fuzzy_match then
			vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 9, 18, 22)
		else
			vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, "BroilActive", 9, 24, 29)
		end
	end

	vim.api.nvim_set_option_value("modifiable", false, { buf = self.buf_id })
end

function Config:toggle_search_mode()
	self.search_mode = (self.search_mode + 1) % 2
	self:render_config_settings()
end

function Config:toggle_sort()
	self.sort_option = (self.sort_option + 1) % 5
	self:render_config_settings()
end

function Config:toggle_sort_order()
	self.sort_order = (self.sort_order + 1) % 2
	self:render_config_settings()
end

function Config:toggle_show_hidden()
	self.show_hidden = not self.show_hidden
	self:render_config_settings()
end

function Config:toggle_special_paths_no_enter()
	self.enter_no_enter_special_paths = not self.enter_no_enter_special_paths
	self:render_config_settings()
end

function Config:toggle_show_special_paths_hide()
	self.show_special_paths_hide = not self.show_special_paths_hide
	self:render_config_settings()
end

function Config:toggle_fuzzy_case_mode()
	self.fzf_case_mode = (self.fzf_case_mode + 1) % 3
	self:render_config_settings()
end

function Config:toggle_match()
	self.fzf_fuzzy_match = not self.fzf_fuzzy_match
	self:render_config_settings()
end

return Config
