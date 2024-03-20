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
  self.deletion_count = 0

  self.buf_id = vim.api.nvim_create_buf(false, true)
  self.win_id = nil
  return editor
end

function Editor:handle_edits(tree)
  self.current_edits = {}
  vim.api.nvim_buf_clear_namespace(tree.buf_id, self.delete_ns_id, 0, -1)
  vim.api.nvim_buf_clear_namespace(tree.buf_id, self.highlight_ns_id, 0, -1)
  self.deletion_count = 0

  for _, bline in ipairs(tree.lines) do
    self:build_deleted_and_remove_children(bline, tree)
  end

  local current_lines = vim.api.nvim_buf_get_lines(tree.buf_id, 0, -1, false)
  for index, line in ipairs(current_lines) do
    tree:draw_line_extmarks(index, line, current_lines)
    self:highlight_new_and_modified(index, line, tree)
    self:build_new_and_edited(index, line, current_lines, tree)
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
    local path_id_above_less_indent = nil
    while line_index > 1 and (not path_id_above_less_indent) do
      line_index = line_index - 1

      local line_above = current_lines[line_index]
      local line_indent_above = line_above:match("^%s*") or ""
      local path_id_above = utils.get_bid_by_match(line_above)

      if (#line_indent_above < #line_indent and path_id_above) then
        path_id_above_less_indent = path_id_above
      end
    end

    -- remove leading whitespace before first char, remove path_id from the end, remove trailing slash for dirs
    local edited_line_w_trailing_slash = line:gsub("^%s*", ""):gsub("%[%d+%]$", "")
    local edited_line, replaced_trailing_slash_count = edited_line_w_trailing_slash:gsub("%/$", "")
    local edited_line_name = vim.fn.fnamemodify(edited_line, ':t')

    -- build the path_to by appending the bline name to the bline above this line
    local parent_bline_by_indent = tree:find_by_id(path_id_above_less_indent)
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
      local id = ('New:' .. index)
      if (path_id) then
        id = tostring(path_id)
      end
      self.current_edits[tostring(id)] = {
        path_from = path_from,
        path_to = path_to,
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

    self.current_edits[tostring(bline.id)] = {
      path_from = bline.path,
      path_to = nil,
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
    local edited = bline.rendered ~= line

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

function Editor:open_edits_float(win_id)
  vim.api.nvim_buf_set_lines(self.buf_id, 0, -1, false, { 'EDITS: ' })
  for _, edit in pairs(self.current_edits) do
    vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false,
      { 'path_from: ' .. tostring(edit.path_from) .. ' path_to: ' .. tostring(edit.path_to) })
  end

  if (self.win_id) then
    return vim.api.nvim_set_current_win(self.win_id)
  end

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
end

function Editor:close_edits_float()
  if (self.win_id) then
    vim.api.nvim_win_close(self.win_id, true)
    self.win_id = nil
  end
end

return Editor
