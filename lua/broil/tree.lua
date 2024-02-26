local Tree = {}
Tree.__index = Tree

--- @param options broil.TreeOptions
function Tree:new(options)
  local tree = {}
  setmetatable(tree, Tree)

  tree.buf_id = options.buf_id
  tree.lines = options.lines
  tree.selected_index = options.selected_index
  tree.win_id = options.win_id

  tree.selection_ns_id = vim.api.nvim_create_namespace('BroilSelection')

  return tree
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
