local utils = require('broil.utils')
local fs = require('broil.fs')
local async = require('plenary.async')

local Editor = {}
Editor.__index = Editor

--- @return broil.Editor
function Editor:new()
  local editor = {}
  setmetatable(editor, Editor)

  self.current_edits = {} -- edits local to a displayed tree, recalculated after each rerender
  self.highlight_ns_id = vim.api.nvim_create_namespace('BroilEditHighlights')
  self.delete_ns_id = vim.api.nvim_create_namespace('BroilDeleteHighlights')
  self.edit_window_ns_id = vim.api.nvim_create_namespace('BroilEditorWindow')
  self.deletion_count = 0

  self.buf_id = vim.api.nvim_create_buf(false, true)
  self.win_id = nil

  self.new_edits_counter = 0
  return editor
end

--- this function gets run async in the rerender, but not async when editing!
--- @param editing boolean -- whether we are after a tree rerender, or after an edit in the tree buffer
function Editor:handle_edits(tree, editing)
  vim.api.nvim_buf_clear_namespace(tree.buf_id, self.delete_ns_id, 0, -1)
  vim.api.nvim_buf_clear_namespace(tree.buf_id, self.highlight_ns_id, 0, -1)
  self.deletion_count = 0

  -- we cannot have deletions in the buffer if we are in a rerender
  for _, bline in ipairs(tree.lines) do
    self:build_deleted_and_remove_children(bline, tree, editing)
  end

  if (not editing) then
    async.util.scheduler() -- allow other tasks to run from time to time
  end

  local current_lines = vim.api.nvim_buf_get_lines(tree.buf_id, 0, -1, false)
  if (editing) then
    for index, line in ipairs(current_lines) do
      self:build_new_and_edited(index, line, current_lines, tree)
    end
  end

  if (editing) then
    self:combine_edits()
  end

  for index, line in ipairs(current_lines) do
    self:highlight_new_and_modified(index, line, tree)
    tree:draw_line_extmarks(index, line, current_lines)
  end

  for index, bline in ipairs(tree.lines) do
    self:highlight_deleted(index, bline, current_lines, tree)
  end

  if (not editing) then
    async.util.scheduler() -- allow other tasks to run from time to time
  end

  if (editing) then
    current_lines = vim.api.nvim_buf_get_lines(tree.buf_id, 0, -1, false)
    self:remove_new_edits_if_removed(tree, current_lines)
  end
end

--- @param line string rendered line of the tree
function Editor:build_new_and_edited(index, line, current_lines, tree)
  if (line ~= '') then -- ignore emtpy lines
    local path_id = utils.get_bid_by_match(line)
    local bline = tree:find_by_id(path_id)

    local path_from = nil
    local path_to = nil

    if (bline and bline.line_type == 'pruning') then
      return
    end

    if (bline) then
      if (bline.file_type == 'directory') then
        path_from = bline:get_dir_path()
      else
        path_from = bline.path
      end
    end

    local parent_bline_dir_by_indent, parent_new_edit_dir_by_indent = self:line_get_parent_by_indent(line,
      index, tree, current_lines)

    -- remove leading whitespace before first char, remove path_id from the end, remove trailing slash for dirs
    local edited_line_w_trailing_slash = line:gsub("^%s*", ""):gsub("%[%d+%]$", ""):gsub("%[%+%d+%]$", "")
    local edited_line, replaced_trailing_slash_count = edited_line_w_trailing_slash:gsub("%/$", "")
    local edited_line_name = vim.fn.fnamemodify(edited_line, ':t')

    local path_head
    if (parent_bline_dir_by_indent ~= nil) then
      path_head = parent_bline_dir_by_indent:get_dir_path()
    elseif (parent_new_edit_dir_by_indent ~= nil) then
      path_head = parent_new_edit_dir_by_indent.path_to
    else
      path_head = tree.lines[1]:get_dir_path()
    end

    if (edited_line_name ~= "") then
      if (path_id == tree.lines[1].id) then
        path_to = edited_line_w_trailing_slash
      else
        path_to = path_head .. edited_line_name

        if (replaced_trailing_slash_count > 0) then
          path_to = path_to .. '/'
        end
      end
    end


    local id = tostring(path_id)
    if (not path_id) then
      local new_id = utils.get_new_id_by_match(line)
      if (new_id) then
        id = new_id
      end
      if (not new_id) then
        id = ('+' .. self.new_edits_counter)
        vim.api.nvim_buf_set_lines(tree.buf_id, index - 1, index, false, { line .. '[' .. id .. ']' })
        self.new_edits_counter = self.new_edits_counter + 1
      end
    end

    if (path_from) then
      path_from = path_from:gsub('\n', '')
    end
    if (path_to) then
      path_to = path_to:gsub('\n', '')
    end

    if (path_from ~= path_to) then
      local status = 'copy'
      if (not path_from) then
        status = 'create'
      end

      if (path_from and path_to) then
        local from_dir = vim.fn.fnamemodify(path_from:gsub("%/$", ""), ':h');
        local to_dir = vim.fn.fnamemodify(path_to:gsub("%/$", ""), ':h');
        if (from_dir == to_dir) then
          status = 'move'
        end
      end

      if (status == 'copy') then
        id = '=' .. id

        if (path_to == nil) then
          return
        end
      end

      local already_staged = nil
      if (self.current_edits[id]) then
        already_staged = self.current_edits[id].staged
      end
      self.current_edits[id] = {
        id = id,
        path_from = path_from,
        path_to = path_to,
        line = line,
        staged = already_staged or false,
        status = status,
        job_out = nil
      }
    else
      self.current_edits[id] = nil
    end
  end
end

function Editor:line_get_parent_by_indent(line, index, tree, current_lines)
  -- iterate backwards from this line in the tree, until we hit a line or edit with a parsable id?
  local line_indent = line:match("^%s*") or ""
  local line_index = index;
  -- build the path_to by appending the bline name to the bline above this line
  local parent_bline_dir_by_indent = nil
  local parent_new_edit_dir_by_indent = nil

  while line_index > 1 do
    line_index = line_index - 1
    local line_above = current_lines[line_index]
    local line_indent_above = line_above:match("^%s*") or ""

    -- check if the line above is a directory with less indent
    -- check if the line above is a new edit directory with less indent
    if (#line_indent_above < #line_indent) then
      local path_id_above = utils.get_bid_by_match(line_above)
      local bline_above = tree:find_by_id(path_id_above)
      if (path_id_above and bline_above.file_type == 'directory') then
        parent_bline_dir_by_indent = bline_above
        break;
      end

      local edit_id_above = utils.get_new_id_by_match(line_above)
      if (edit_id_above) then
        local edit_above = self.current_edits[edit_id_above]
        if (edit_above and edit_above.status == 'create' and edit_above.path_to:find('%/$')) then
          parent_new_edit_dir_by_indent = edit_above
          break
        end
      end
    end
  end

  return parent_bline_dir_by_indent, parent_new_edit_dir_by_indent
end

function Editor:build_deleted_and_remove_children(bline, tree, editing)
  if (not bline or bline.line_type == 'pruning') then
    return
  end

  local id = '-' .. tostring(bline.id)

  if (not editing and self.current_edits[id]) then
    return tree:remove_children({ bline.id })
  end

  local current_line_exists = false
  local current_lines = vim.api.nvim_buf_get_lines(tree.buf_id, 0, -1, false)

  -- check if a line with the bid exists after editing
  local path_id = nil
  for index, line in ipairs(current_lines) do
    path_id = utils.get_bid_by_match(line)
    if (path_id == bline.id) then
      local parent_bline_dir_by_indent = self:line_get_parent_by_indent(line,
        index, tree, current_lines)

      if (not parent_bline_dir_by_indent or not bline.parent_id or parent_bline_dir_by_indent.id == bline.parent_id) then
        current_line_exists = true
        break
      end
    end
  end

  -- if not, we deleted it
  if (not current_line_exists) then
    -- make sure all children are deleted aswell!
    if (bline.file_type == 'directory') then
      tree:remove_children(bline.children)
    end

    -- build the actual edit
    local path_from = bline.path
    if (bline.file_type == 'directory') then
      path_from = bline.path .. '/'
    end

    local already_staged = nil
    if (self.current_edits[id]) then
      already_staged = self.current_edits[id].staged
    end
    self.current_edits[id] = {
      id = id,
      path_from = path_from,
      path_to = nil,
      staged = already_staged or false,
      status = 'delete',
      line = nil,
      job_out = nil
    }
  else
    -- the line exists, so remove the delete edit if it exists
    self.current_edits[id] = nil
  end
end

--- 1. combine deletes: eg. if you delete a folder, we should only have edits for the folder and not for all of its children
--- 2. combine delete and copy to move. If you deleted a file and copied it else where, we move it instead.
function Editor:combine_edits()
  for _, edit in pairs(self.current_edits) do
    if (edit.status == 'delete') then
      for _, edit2 in pairs(self.current_edits) do
        -- combine deletes
        if (edit2.status == 'delete' and edit.id ~= edit2.id and edit2.path_from:find(edit.path_from)) then
          self.current_edits[edit2.id] = nil
        end

        -- combine delete and copy to move
        if (edit2.status == 'copy' and edit.id ~= edit2.id and edit.path_from == edit2.path_from) then
          self.current_edits[edit2.id] = nil -- remove copy
          self.current_edits[edit.id] = nil  -- remove delete
          -- create move
          edit2.status = 'move'
          edit2.id = edit2.id:gsub("+", '')
          self.current_edits[edit2.id] = edit2
        end
      end
    end

    if (edit.status == 'move') then
      for _, edit2 in pairs(self.current_edits) do
        -- remove move if there is a delete with the same from path
        if (edit2.status == 'delete' and edit.id ~= edit2.id and edit.path_from == edit2.path_from) then
          self.current_edits[edit.id] = nil
          break;
        end
      end
    end
  end
end

function Editor:highlight_new_and_modified(index, line, tree)
  if (line == nil or line == '') then
    return
  end

  local edit_id = utils.get_edit_id_by_match(line)
  local edit = self.current_edits[edit_id] or self.current_edits['=' .. (edit_id or '')]

  if (edit) then
    -- highlight the edited line
    if (edit.status == 'copy') then
      vim.api.nvim_buf_set_extmark(tree.buf_id, self.highlight_ns_id, index - 1, 0, {
        sign_text = "┃",
        sign_hl_group = 'BroilCopy',
        invalidate = true
      })
    elseif (edit.status == 'create') then
      vim.api.nvim_buf_set_extmark(tree.buf_id, self.highlight_ns_id, index - 1, 0, {
        sign_text = '┃',
        sign_hl_group = 'BroilAdded',
        invalidate = true
      })
    elseif (edit.status == 'move') then
      vim.api.nvim_buf_set_extmark(tree.buf_id, self.highlight_ns_id, index - 1, 0, {
        sign_text = '┃',
        sign_hl_group = 'BroilEdited',
        invalidate = true
      })
    end
  else
    -- remove the highlight
    vim.api.nvim_buf_clear_namespace(tree.buf_id, self.highlight_ns_id, index, index + 1)
  end
end

function Editor:highlight_deleted(index, bline, current_lines, tree)
  if (not bline or bline.line_type == 'pruning') then
    return
  end

  -- check if a line with the bid exists after editing
  local current_line_exists = false
  for _, line in ipairs(current_lines) do
    local path_id = utils.get_bid_by_match(line)
    if (path_id == bline.id) then
      current_line_exists = true
      break
    end
  end

  -- if not, we deleted it
  if (not current_line_exists) then
    local line_ext_marks = vim.api.nvim_buf_get_extmarks(tree.buf_id, self.delete_ns_id, { index - 2, 0 },
      { index - 1, -1 }, {})

    if (#line_ext_marks == 0) then
      vim.api.nvim_buf_set_extmark(tree.buf_id, self.delete_ns_id, index - 1 - self.deletion_count, 0, {
        sign_text = '▔',
        sign_hl_group = 'BroilDeleted',
        invalidate = true,
        strict = false
      })
    end

    self.deletion_count = self.deletion_count + 1
  end
end

function Editor:render_edits()
  vim.api.nvim_set_option_value('modifiable', true, { buf = self.buf_id })

  local line_number = 0
  local unstaged_edits = {}
  local staged_edits = {}
  for _, edit in pairs(self.current_edits) do
    if (edit) then
      if (edit.staged) then
        table.insert(staged_edits, edit)
      else
        table.insert(unstaged_edits, edit)
      end
    end
  end
  vim.api.nvim_buf_set_lines(self.buf_id, 0, -1, false,
    { 'Unstaged edits: (' .. #unstaged_edits .. ')', '' })
  line_number = line_number + 2
  vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilEditorHeadline', 0, 0, 15)
  for _, unstaged_edit in pairs(unstaged_edits) do
    self:render_edit(line_number, unstaged_edit)
    line_number = line_number + 1
  end

  vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false,
    { '', 'Staged edits: (' .. #staged_edits .. ')', '' })
  line_number = line_number + 3
  vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilEditorHeadline', line_number - 2, 0, 13)

  for _, staged_edit in pairs(staged_edits) do
    self:render_edit(line_number, staged_edit)
    line_number = line_number + 1
  end

  vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf_id })
end

function Editor:render_edit(line_number, edit)
  local line_status = 'MOVE      '
  if (edit.status == 'moved') then
    line_status = 'MOVED     '
  elseif (edit.status == 'delete') then
    line_status = 'DELETE    '
  elseif (edit.status == 'deleted') then
    line_status = 'DELETED   '
  elseif (edit.status == 'create') then
    line_status = 'CREATE    '
  elseif (edit.status == 'created') then
    line_status = 'CREATED    '
  elseif (edit.status == 'copy') then
    line_status = 'COPY       '
  elseif (edit.status == 'copied') then
    line_status = 'COPIED     '
  elseif (edit.status == 'queued') then
    line_status = 'QUEUED    '
  elseif (edit.status == 'error') then
    line_status = 'ERROR     '
  end

  local rendered = tostring(edit.path_from) ..
      ' -> ' .. tostring(edit.path_to) .. ' [' .. edit.id .. ']'

  vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, { line_status .. rendered })

  if (edit.status == 'delete') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilDeleted', line_number, 0, 7)
  elseif (edit.status == 'create') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilAdded', line_number, 0, 7)
  elseif (edit.status == 'copy') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilCopy', line_number, 0, 4)
  elseif (edit.status == 'move') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilEdited', line_number, 0, 7)
  elseif (edit.status == 'queued') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilQueued', line_number, 0, 7)
  elseif (edit.status == 'error') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilDeleted', line_number, 0, 7)
  elseif (edit.status == 'deleted' or edit.status == 'created' or edit.status == 'moved' or edit.status == 'copied') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilInfo', line_number, 0, 7)
  end

  if (edit.job_out) then
    vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, edit.job_out)
    for i = 0, #edit.job_out do
      vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilPruningLine', line_number + 1 + i, 0, -1)
    end
  end
end

function Editor:open_edits_float(win_id)
  if (self.win_id) then
    return vim.api.nvim_set_current_win(self.win_id)
  end

  for e_id, edit in pairs(self.current_edits) do
    if (edit.status == 'created' or edit.status == 'moved' or edit.status == 'deleted' or edit.status == 'copied') then
      self.current_edits[e_id] = nil
    end
  end

  self:render_edits()
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

  vim.api.nvim_win_call(self.win_id, function()
    vim.fn.matchadd('Conceal', [[\[.*\]$]])
  end)
end

function Editor:close_edits_float()
  if (self.win_id) then
    vim.api.nvim_win_close(self.win_id, true)
    self.win_id = nil
  end
end

function Editor:stage_edit()
  local cursor_y = vim.api.nvim_win_get_cursor(0)[1]
  local cursor_line = vim.api.nvim_buf_get_lines(self.buf_id, cursor_y - 1, cursor_y, false)[1]

  local edit_id = utils.get_edit_id_by_match(cursor_line)
  if (edit_id) then
    self.current_edits[edit_id].staged = true
    self:render_edits()
    vim.api.nvim_win_set_cursor(0, { cursor_y, 0 })
  end
end

function Editor:stage_edit_range()
  local range_start = vim.fn.getpos('v')[2]
  local range_end = vim.fn.getcurpos()[2]

  if (range_start > range_end) then
    local temp = range_start
    range_start = range_end
    range_end = temp
  end
  for i = range_start, range_end do
    local line = vim.api.nvim_buf_get_lines(self.buf_id, i - 1, i, false)[1]
    local edit_id = utils.get_edit_id_by_match(line)
    if (edit_id) then
      self.current_edits[edit_id].staged = true
    end
  end
  local esc = vim.api.nvim_replace_termcodes('<esc>', true, false, true)
  vim.api.nvim_feedkeys(esc, 'x', false)
  self:render_edits()
  vim.api.nvim_win_set_cursor(0, { range_start, 0 })
end

function Editor:stage_all_edits()
  local cursor_y = vim.api.nvim_win_get_cursor(0)[1]
  local current_lines = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)
  for _, line in ipairs(current_lines) do
    local edit_id = utils.get_edit_id_by_match(line)
    if (edit_id) then
      self.current_edits[edit_id].staged = true
    end
  end
  self:render_edits()
  vim.api.nvim_win_set_cursor(0, { cursor_y, 0 })
end

function Editor:unstage_edit()
  local cursor_y = vim.api.nvim_win_get_cursor(0)[1]
  local cursor_line = vim.api.nvim_buf_get_lines(self.buf_id, cursor_y - 1, cursor_y, false)[1]

  local edit_id = utils.get_edit_id_by_match(cursor_line)
  if (edit_id) then
    self.current_edits[edit_id].staged = false
    self:render_edits()
    vim.api.nvim_win_set_cursor(0, { cursor_y, 0 })
  end
end

function Editor:unstage_edit_range()
  local range_start = vim.fn.getpos('v')[2]
  local range_end = vim.fn.getcurpos()[2]

  if (range_start > range_end) then
    local temp = range_start
    range_start = range_end
    range_end = temp
  end
  for i = range_start, range_end do
    local line = vim.api.nvim_buf_get_lines(self.buf_id, i - 1, i, false)[1]
    local edit_id = utils.get_edit_id_by_match(line)
    if (edit_id) then
      self.current_edits[edit_id].staged = false
    end
  end
  local esc = vim.api.nvim_replace_termcodes('<esc>', true, false, true)
  vim.api.nvim_feedkeys(esc, 'x', false)
  self:render_edits()
  vim.api.nvim_win_set_cursor(0, { range_start, 0 })
end

function Editor:unstage_all_edits()
  local cursor_y = vim.api.nvim_win_get_cursor(0)[1]
  local current_lines = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)
  for _, line in ipairs(current_lines) do
    local edit_id = utils.get_edit_id_by_match(line)
    if (edit_id) then
      self.current_edits[edit_id].staged = false
    end
  end
  self:render_edits()
  vim.api.nvim_win_set_cursor(0, { cursor_y, 0 })
end

function Editor:undo_edit()
  local cursor_y = vim.api.nvim_win_get_cursor(0)[1]
  local cursor_line = vim.api.nvim_buf_get_lines(self.buf_id, cursor_y - 1, cursor_y, false)[1]
  local edit_id = utils.get_edit_id_by_match(cursor_line)
  if (edit_id) then
    self.current_edits[edit_id] = nil
  end
  self:render_edits()
  local new_cursor_pos = cursor_y - 1
  if (new_cursor_pos < 1) then
    new_cursor_pos = 1
  end
  vim.api.nvim_win_set_cursor(0, { new_cursor_pos, 0 })
end

function Editor:undo_edit_range()
  local range_start = vim.fn.getpos('v')[2]
  local range_end = vim.fn.getcurpos()[2]

  if (range_start > range_end) then
    local temp = range_start
    range_start = range_end
    range_end = temp
  end

  local removed_edits = 0
  for i = range_start, range_end do
    local line = vim.api.nvim_buf_get_lines(self.buf_id, i - 1, i, false)[1]
    local edit_id = utils.get_edit_id_by_match(line)
    if (edit_id) then
      self.current_edits[edit_id] = nil
      removed_edits = removed_edits + 1
    end
  end

  self:render_edits()

  local new_cursor_pos = range_start - removed_edits
  if (new_cursor_pos < 1) then
    new_cursor_pos = 1
  end
  vim.api.nvim_win_set_cursor(0, { new_cursor_pos, 0 })
end

function Editor:apply_staged_edits(callback)
  for _, edit in pairs(self.current_edits) do
    if (edit.staged) then
      if (edit.status == 'delete') then
        fs:delete(edit.path_from, vim.schedule_wrap(function(job_out, exit_code)
          if (exit_code == 0) then
            self.current_edits[edit.id].status = 'deleted'
          else
            self.current_edits[edit.id].status = 'error'
          end
          self.current_edits[edit.id].job_out = job_out
          self:render_edits()
          callback()
        end))
      elseif (edit.status == 'create') then
        fs:create(edit.path_to, vim.schedule_wrap(function(job_out, exit_code)
          if (exit_code == 0) then
            self.current_edits[edit.id].status = 'created'
          else
            self.current_edits[edit.id].status = 'error'
          end

          self.current_edits[edit.id].job_out = job_out
          self:render_edits()
          callback()
        end))
      elseif (edit.status == 'move') then
        fs:move(edit.path_from, edit.path_to, vim.schedule_wrap(function(job_out, exit_code)
          if (exit_code == 0) then
            self.current_edits[edit.id].status = 'moved'
          else
            self.current_edits[edit.id].status = 'error'
          end

          self.current_edits[edit.id].job_out = job_out
          self:render_edits()
          callback()
        end))
      elseif (edit.status == 'copy') then
        fs:copy(edit.path_from, edit.path_to, vim.schedule_wrap(function(job_out, exit_code)
          if (exit_code == 0) then
            self.current_edits[edit.id].status = 'copied'
          else
            self.current_edits[edit.id].status = 'error'
          end

          self.current_edits[edit.id].job_out = job_out
          self:render_edits()
          callback()
        end))
      end
      -- remove the edit after applying it
      self.current_edits[edit.id].status = 'queued'
      self:render_edits()
    end
  end
end

function Editor:append_new_lines_from_edits(tree)
  local current_lines = vim.api.nvim_buf_get_lines(tree.buf_id, 0, -1, false)
  for _, edit in pairs(self.current_edits) do
    if (edit.status == 'create') then
      local path_to = edit.path_to
      local path_to_no_trailing_slash = path_to:gsub("/$", "")
      local path_to_dir = vim.fn.fnamemodify(path_to_no_trailing_slash, ':h')

      for i, line in ipairs(current_lines) do
        local path_id = utils.get_bid_by_match(line)
        local bline = tree:find_by_id(path_id)

        if (bline and bline.path == path_to_dir) then
          local indent = string.rep(' ', bline.depth * 3) .. string.rep(' ', 6)
          local name = vim.fn.fnamemodify(path_to, ':t')
          vim.api.nvim_buf_set_lines(tree.buf_id, i, i, false, { indent .. name .. '[' .. edit.id .. ']' })
          break
        end
      end
    end
  end
end

function Editor:remove_new_edits_if_removed(tree, current_lines)
  for _, edit in pairs(self.current_edits) do
    if (edit.status == 'create') then
      -- check if current_lines contains the created new line, if not. Remove it.
      local found = false
      for _, line in ipairs(current_lines) do
        if (line == edit.line) then
          found = true
          break
        end
      end

      if (not found) then
        local edit_path_to_dir = vim.fn.fnamemodify(edit.path_to:gsub('%/$', ''), ':h')
        -- check if we could have rendered the edit by moving upwards through current lines and checking if the path of the edit would have been rendered
        local could_have_been_rendered = false
        for _, line in ipairs(current_lines) do
          local path_id = utils.get_bid_by_match(line)
          local bline = tree:find_by_id(path_id)
          if (bline and bline.path == edit_path_to_dir) then
            could_have_been_rendered = true
            break
          end
        end

        if (could_have_been_rendered) then
          self.current_edits[edit.id] = nil
        end
      end
    end
  end
end

return Editor
