local Tree = {}
Tree.__index = Tree

local webdevicons = require('nvim-web-devicons')

--- @param options broil.TreeOptions
function Tree:new(options)
  local tree = {}
  setmetatable(tree, Tree)

  tree.pattern = options.pattern
  tree.buf_id = options.buf_id
  tree.lines = options.lines
  tree.highest_score_index = options.highest_score_index
  tree.open_path_index = options.open_path_index
  tree.win_id = options.win_id

  tree.selection_ns_id = vim.api.nvim_create_namespace('BroilSelection')
  tree.ext_marks_ns_id = vim.api.nvim_create_namespace('BroilTreeExtMarks')
  tree.highlight_ns_id = vim.api.nvim_create_namespace('BroilTreeHighlights')

  return tree
end

function Tree:render()
  vim.api.nvim_buf_set_lines(self.buf_id, 0, -1, false, {})
  vim.api.nvim_buf_clear_namespace(self.buf_id, self.ext_marks_ns_id, 0, -1)

  for index, bline in ipairs(self.lines) do
    local rendered_line = self:render_name(bline)

    -- Remove newline characters from the rendered_line
    rendered_line = rendered_line:gsub('\n', '')

    -- Render the line
    vim.api.nvim_buf_set_lines(self.buf_id, index - 1, index - 1, false, { rendered_line })


    -- Render TreeLines
    local tree_lines = self:render_tree_lines(bline, index)
    vim.api.nvim_buf_set_extmark(self.buf_id, self.ext_marks_ns_id, index - 1, 0,
      { virt_text = { { tree_lines, 'BroilTreeLines' } }, virt_text_pos = 'inline' })

    -- Render File Icons
    local file_icon, color, file_extension = self:render_icon(bline)
    vim.api.nvim_command('highlight BroilTreeIcons_' .. file_extension .. ' guifg=' .. color) -- highlight Icon in color
    vim.api.nvim_buf_set_extmark(self.buf_id, self.ext_marks_ns_id, index - 1, 0,
      { virt_text = { { file_icon, 'BroilTreeIcons_' .. file_extension } }, virt_text_pos = 'inline' })


    -- Render Icon highlights
    if (bline.file_type == 'directory') then
      vim.api.nvim_command('highlight BroilDirLine guifg=#89b4fa')
      vim.api.nvim_buf_add_highlight(self.buf_id, self.highlight_ns_id, 'BroilDirLine', index - 1, 0, -1)
    end

    if (bline.line_type == 'pruning') then
      vim.api.nvim_command('highlight BroilPruningLine guifg=#a6adc8')
      vim.api.nvim_buf_add_highlight(self.buf_id, self.highlight_ns_id, 'BroilPruningLine', index - 1, 0, -1)
    end

    -- Render relative path dir parts
    if (self.pattern and bline.fzf_pos) then
      vim.api.nvim_command('highlight BroilRelativeLine guifg=#74c7ec')
      local end_dir = rendered_line:find("/[^/]*$")
      if end_dir then
        vim.api.nvim_buf_add_highlight(self.buf_id, self.highlight_ns_id, 'BroilRelativeLine', index - 1, 0, end_dir - 1)
      end
    end

    -- search filter highlighting
    if bline.fzf_pos then
      vim.api.nvim_command('highlight BroilSearchTerm guifg=#f9e2af')
      for _, idx in ipairs(bline.fzf_pos) do
        vim.api.nvim_buf_add_highlight(self.buf_id, self.highlight_ns_id, 'BroilSearchTerm', index - 1, idx - 1,
          idx)
      end
    end
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

function Tree:render_tree_lines(bline, bline_index)
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
      -- We dont want to add space right before the line, as that space if reserved for a file icon
      if depth ~= bline.depth then
        rendered_branch = rendered_branch .. '   '
      end
    end
  end

  return rendered_branch
end

function Tree:render_icon(bline)
  if (bline.file_type == 'directory') then
    return '  ', '#89b4fa', 'directory'
  end

  if (bline.line_type == 'pruning') then
    return '󱞃  ', '#a6adc8', 'pruning'
  end

  -- TODO: better way to handle file extensions?
  local file_extension = bline.name:match("%.([^%.]+)$")
  if (file_extension) then
    file_extension = file_extension:gsub("%W", "_") -- This will replace any character that is not a letter or a digit with an underscore, ensuring that `line_filetype` is always a valid group name.
  end

  local icon, color = webdevicons.get_icon_color(bline.name, file_extension)
  return icon .. '  ', color, file_extension or 'unknown'
end

function Tree:initial_selection()
  vim.schedule(function()
    if (self.pattern ~= '') then
      vim.api.nvim_win_set_cursor(self.win_id, { self.highest_score_index, 0 })
    else -- open the path
      vim.api.nvim_win_set_cursor(self.win_id, { self.open_path_index, 0 })
    end
  end)
end

function Tree:has_branch(line_index, depth)
  if (line_index > #self.lines) then
    return false
  end

  local line = self.lines[line_index]
  return depth <= line.depth and line.left_branches[tostring(depth)]
end

function Tree:select_next()
  -- Get the current cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(self.win_id)
  local cursor_y = cursor_pos[1] + 1

  -- reset the render index if out of bounds of the window
  local lines = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)
  if (cursor_y > #lines - 1) then
    cursor_y = 1
  end

  vim.api.nvim_win_set_cursor(self.win_id, { cursor_y, 0 })
end

function Tree:select_prev()
  -- Get the current cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(self.win_id)
  local cursor_y = cursor_pos[1] - 1

  -- reset the render index if out of bounds of the window
  local lines = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)
  if (cursor_y < 1) then
    cursor_y = #lines - 1
  end

  vim.api.nvim_win_set_cursor(self.win_id, { cursor_y, 0 })
end

return Tree
