local Config = {
  mappings = {
    -- general
    help = '?',
    close = '<C-q>',
    pop_history = '<C-p>',
    open_edits_float = '<C-e>',
    open_config_float = '<C-c>',

    -- search
    select_next_node = '<C-j>',
    select_next_node_normal = 'j',
    select_prev_node = '<C-k>',
    select_prev_node_normal = 'k',
    open_selected_node = '<CR>',
    open_selected_node2 = '<C-l>',
    open_parent_dir = '<C-h>',

    -- edits window
    stage_edit = 's',
    stage_all_edits = 'S',
    stage_all_edits2 = '<c-s>',
    unstage_edit = 'u',
    unstage_all_edits = 'U',
    undo_edit = 'x',
    apply_staged_edits = '<c-y>'
  },
  special_paths = {
    ["media"] = "no-enter",
    [".git"] = "no-enter",
    ["node_modules"] = "no-enter",
    ["vendor"] = "no-enter",
    [".svelte-kit"] = "no-enter",
    ["dist"] = "no-enter",
    ["target"] = "no-enter",
    ["debug"] = "no-enter",
    ["release"] = "no-enter",
    ["build"] = "no-enter",
    ["tmp"] = "no-enter",
    [".next"] = "no-enter",
    [".DS_Store"] = "hide",
  },

  -- runtime configs
  fzf_case_mode = 0,  -- case_mode: number with 0 = smart_case, 1 = ignore_case, 2 = respect_case
  fzf_fuzzy_match = true,
  show_hidden = true, -- files/dirs with '.'
  sort_option = 0,    -- 0 = 'TypeDirsFirst',  1 = 'TypeDirsLast'
  file_size_preview_limit_mb = 5,

  shell = vim.o.shell,
  shell_exec_flag = '-c', -- will result in `sh -c 'command_below'`

  -- filesystem commands
  rm_command = 'rm', -- you could use a trash command here. Or rm --trash for nushell...
  mv_command = 'mv',
  mkdir_command = 'mkdir -p',
  touch_command = 'touch',

  -- internal config window
  buf_id = vim.api.nvim_create_buf(false, true),
  win_id = nil,
  config_window_ns_id = vim.api.nvim_create_namespace('BroilConfigWindow')
}

--- @param opts table|nil configuration See |broil.config|.
Config.set = function(opts)
  local new_conf = vim.tbl_deep_extend("keep", opts or {}, Config)
  for k, v in pairs(new_conf) do
    Config[k] = v
  end
end

function Config:open_config_float(win_id)
  if (self.win_id) then
    return vim.api.nvim_set_current_win(self.win_id)
  end
  vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf_id })

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
  vim.api.nvim_command('stopinsert')
end

function Config:close_config_float()
  if (self.win_id) then
    vim.api.nvim_win_close(self.win_id, true)
    self.win_id = nil
  end
end

function Config:render_config_settings()
  vim.api.nvim_set_option_value('modifiable', true, { buf = self.buf_id })

  vim.api.nvim_buf_set_lines(self.buf_id, 0, -1, false,
    { 'Toggle Settings:', '' })
  vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilEditorHeadline', 0, 0, 15)

  -- Sort:
  vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false,
    { '-s: Sort by [dir_first, file_first, size, alphabetical] (TODO)' })
  vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilInfo', 2, 0, 2)
  vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilInactive', 2, 12, -1)
  if (self.sort_option == 0) then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilActive', 2, 13, 22)
  elseif (self.sort_option == 1) then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilActive', 2, 24, 34)
  elseif (self.sort_option == 2) then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilActive', 2, 36, 40)
  elseif (self.sort_option == 3) then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilActive', 2, 42, 54)
  end

  -- Show hidden:
  vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false,
    { '-h: Show hidden [true, false]' })
  vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilInfo', 3, 0, 2)
  vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilInactive', 3, 16, -1)
  if (self.show_hidden) then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilActive', 3, 17, 21)
  else
    vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilActive', 3, 23, 28)
  end

  -- Fuzzy case_mode
  vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false,
    { '-C: Fuzzy case mode [smart_case, ignore_case, respect_case]' })
  vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilInfo', 4, 0, 2)
  vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilInactive', 4, 20, -1)
  if (self.fzf_case_mode == 0) then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilActive', 4, 21, 31)
  elseif (self.fzf_case_mode == 1) then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilActive', 4, 33, 44)
  elseif (self.fzf_case_mode == 2) then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilActive', 4, 45, 58)
  end

  -- Fuzzy match
  vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false,
    { '-F: Fuzzy search [true, false]' })
  vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilInfo', 5, 0, 2)
  vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilInactive', 5, 17, -1)
  if (self.fzf_fuzzy_match) then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilActive', 5, 18, 22)
  else
    vim.api.nvim_buf_add_highlight(self.buf_id, self.config_window_ns_id, 'BroilActive', 5, 24, 29)
  end

  vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf_id })
end

function Config:toggle_sort()
  self.sort_option = (self.sort_option + 1) % 4
  self:render_config_settings()
end

function Config:toggle_show_hidden()
  self.show_hidden = not self.show_hidden
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
