local utils = require('broil.utils')

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
  return editor
end

function Editor:handle_edits(tree)
  vim.api.nvim_buf_clear_namespace(tree.buf_id, self.delete_ns_id, 0, -1)
  vim.api.nvim_buf_clear_namespace(tree.buf_id, self.highlight_ns_id, 0, -1)
  self.deletion_count = 0

  for _, bline in ipairs(tree.lines) do
    self:build_deleted_and_remove_children(bline, tree)
  end

  local current_lines = vim.api.nvim_buf_get_lines(tree.buf_id, 0, -1, false)
  for index, line in ipairs(current_lines) do
    self:build_new_and_edited(index, line, current_lines, tree)
    tree:draw_line_extmarks(index, line, current_lines)
    self:highlight_new_and_modified(index, line, tree)
  end

  for index, bline in ipairs(tree.lines) do
    self:highlight_deleted(index, bline, current_lines, tree)
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
      goto continue
    end

    if (bline) then
      if (bline.file_type == 'directory') then
        path_from = bline:get_dir_path()
      else
        path_from = bline.path
      end
    end

    -- iterate backwards from this line in the tree, until we hit a line with a parsable bid?
    local line_indent = line:match("^%s*") or ""
    local line_index = index;
    -- build the path_to by appending the bline name to the bline above this line
    local parent_bline_by_indent = nil

    while line_index > 1 and (not parent_bline_by_indent) do
      line_index = line_index - 1

      local line_above = current_lines[line_index]
      local line_indent_above = line_above:match("^%s*") or ""
      local path_id_above = utils.get_bid_by_match(line_above)
      local bline_above = tree:find_by_id(path_id_above)

      if (#line_indent_above < #line_indent and path_id_above and bline_above.file_type == 'directory') then
        parent_bline_by_indent = bline_above
      end
    end

    -- remove leading whitespace before first char, remove path_id from the end, remove trailing slash for dirs
    local edited_line_w_trailing_slash = line:gsub("^%s*", ""):gsub("%[%d+%]$", "")
    local edited_line, replaced_trailing_slash_count = edited_line_w_trailing_slash:gsub("%/$", "")
    local edited_line_name = vim.fn.fnamemodify(edited_line, ':t')

    local path_head
    if (parent_bline_by_indent ~= nil) then
      path_head = parent_bline_by_indent:get_dir_path()
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


    if (path_from ~= path_to) then
      local id = ('+' .. index)
      if (path_id) then
        id = tostring(path_id)
      end
      self.current_edits[tostring(id)] = {
        id = id,
        path_from = path_from,
        path_to = path_to,
        staged = false
      }
    end
  end

  ::continue::
end

function Editor:build_deleted_and_remove_children(bline, tree)
  local current_lines = vim.api.nvim_buf_get_lines(tree.buf_id, 0, -1, false)
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
    if (bline.file_type == 'directory') then
      tree:remove_children(bline.children)
    end

    local path_from = bline.path
    if (bline.file_type == 'directory') then
      path_from = bline.path .. '/'
    end
    self.current_edits[tostring(bline.id)] = {
      id = bline.id,
      path_from = path_from,
      path_to = nil,
      staged = false
    }
  end
end

function Editor:highlight_new_and_modified(index, line, tree)
  if (line == nil or line == '') then
    return
  end

  local path_id = utils.get_bid_by_match(line)
  local bline = tree:find_by_id(path_id)

  if (bline) then
    local edited = self.current_edits[tostring(bline.id)]

    if (edited) then
      -- highlight the line as edited
      vim.api.nvim_buf_set_extmark(tree.buf_id, self.highlight_ns_id, index - 1, 0, {
        sign_text = '┃',
        sign_hl_group = 'BroilEdited',
        invalidate = true
      })
    else
      -- remove the highlight
      vim.api.nvim_buf_clear_namespace(tree.buf_id, self.highlight_ns_id, index, index + 1)
    end
  else
    vim.api.nvim_buf_set_extmark(tree.buf_id, self.highlight_ns_id, index - 1, 0, {
      sign_text = '┃',
      sign_hl_group = 'BroilAdded',
      invalidate = true
    })
  end
end

function Editor:highlight_deleted(index, bline, current_lines, tree)
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
        invalidate = true
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
  local line_status = 'EDITED    '
  if (edit.path_to == nil) then
    line_status = 'DELETED   '
  end
  if (edit.path_from == nil) then
    line_status = 'NEW       '
  end

  local rendered = tostring(edit.path_from) ..
      ' -> ' .. tostring(edit.path_to) .. ' [' .. edit.id .. ']'

  vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, { line_status .. rendered })

  if (line_status == 'DELETED   ') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilDeleted', line_number, 0, 7)
  elseif (line_status == 'NEW       ') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilAdded', line_number, 0, 7)
  elseif (line_status == 'EDITED    ') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.edit_window_ns_id, 'BroilEdited', line_number, 0, 7)
  end
end

function Editor:open_edits_float(win_id)
  if (self.win_id) then
    return vim.api.nvim_set_current_win(self.win_id)
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

function Editor:apply_staged_edits()
  print("todo apply staged edits")
end

return Editor
