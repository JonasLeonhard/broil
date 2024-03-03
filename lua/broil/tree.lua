local Tree = {}
Tree.__index = Tree

--- @param options broil.TreeOptions
function Tree:new(options)
  local tree = {}
  setmetatable(tree, Tree)

  tree.pattern = options.pattern
  tree.buf_id = options.buf_id
  tree.lines = options.lines
  tree.selected_index = options.selected_index
  tree.win_id = options.win_id

  tree.selection_ns_id = vim.api.nvim_create_namespace('BroilSelection')

  return tree
end

function Tree:render()
  vim.api.nvim_buf_set_lines(self.buf_id, 0, -1, false, {})
  for index, bline in ipairs(self.lines) do
    -- local indent = string.rep('  ', bline.depth - 1)

    vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false,
      { self:render_branch_icons(bline, index) ..
      self:render_name(bline) .. ' dbg: ' .. bline.depth })
  end
end

function Tree:render_name(bline)
  if (bline.parent_id == nil) then -- the root bline
    return bline.path
  end

  if self.pattern == '' then
    return bline.name
  end

  return bline.relative_path
end

function Tree:render_branch_icons(bline, bline_index)
  local rendered_branch = ''

  for depth = 0, bline.depth do
    if (bline.left_branches[tostring(depth)]) then
      if (self:has_branch(bline_index + 1, depth)) then
        if depth == bline.depth - 1 then
          rendered_branch = rendered_branch .. '├──'
        else
          rendered_branch = rendered_branch .. '│  '
        end
      else
        rendered_branch = rendered_branch .. "└──"
      end
    else
      rendered_branch = rendered_branch .. '   '
    end
  end

  return rendered_branch
end

function Tree:render_selection()
  if (self.selected_index) then
    vim.schedule(function()
      -- reset the render index if out of bounds of the window
      local lines = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)
      if (self.selected_index > #lines - 1) then
        self.selected_render_index = #lines - 1
      end

      vim.api.nvim_buf_clear_namespace(self.buf_id, self.selection_ns_id, 0, -1)
      vim.api.nvim_command('highlight BroilSelection guibg=#45475a')
      vim.api.nvim_buf_add_highlight(self.buf_id, self.selection_ns_id, 'BroilSelection', self.selected_index, 0,
        -1)

      -- Set the cursor to the selected line and scroll to it
      vim.api.nvim_win_set_cursor(self.win_id, { self.selected_index + 1, 0 })
    end)
  end
end

function Tree:has_branch(line_index, depth)
  if (line_index >= #self.lines) then
    return false
  end

  local line = self.lines[line_index]
  return depth <= line.depth and line.left_branches[tostring(depth)]
end

function Tree:select_next()
  local new_index = self.selected_index + 1
  local lines = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)

  if (new_index > #lines - 1) then
    self.selected_index = 1
  else
    self.selected_index = new_index
  end

  self:render_selection()
end

function Tree:select_prev()
  local lines = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)
  local new_index = (self.selected_index or #lines - 1) - 1

  if (new_index < 1) then
    local last_line_index = #lines - 1
    if (last_line_index < 0) then
      return
    end
    self.selected_index = last_line_index
  else
    self.selected_index = new_index
  end

  self:render_selection()
end

return Tree
