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
  tree.conceal_marks_ns_id = vim.api.nvim_create_namespace('BroilConcealMarks')
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

    -- render conceal ids
    local conceal_id = '[' .. bline.id .. ']'
    rendered_line = rendered_line .. conceal_id

    -- render indentation for icons
    local tree_lines = self:render_tree_lines(bline, index)
    local tree_lines_length = bline.depth * 3

    local file_icon, color, file_extension = self:render_icon(bline)
    local file_icon_length = 3

    local indent = string.rep(' ', tree_lines_length) .. string.rep(' ', file_icon_length)
    rendered_line = indent .. rendered_line

    -- Render the line
    vim.api.nvim_buf_set_lines(self.buf_id, index - 1, index - 1, false, { rendered_line })

    -- Render TreeLines
    local mark_id = vim.api.nvim_buf_set_extmark(self.buf_id, self.ext_marks_ns_id, index - 1, 0,
      {
        virt_text = { { tree_lines, 'BroilTreeLines' }, { file_icon, 'BroilTreeIcons_' .. file_extension } },
        virt_text_pos = 'overlay',
        invalidate = true,
      })

    -- Render File Icons
    vim.api.nvim_command('highlight BroilTreeIcons_' .. file_extension .. ' guifg=' .. color) -- highlight Icon in color

    -- remove rendered marks on changes
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
      buffer = self.buf_id,
      callback = function()
        local mark_pos = vim.api.nvim_buf_get_extmark_by_id(self.buf_id, self.ext_marks_ns_id, mark_id,
          { details = true })
        if (not mark_pos[1] and not mark_pos[2]) then
          return
        end
        local marks_of_line = vim.api.nvim_buf_get_extmarks(self.buf_id, self.ext_marks_ns_id, { mark_pos[1], 0 },
          { mark_pos[1], -1 }, {})

        -- delete all marks but the first if multiple are in one line
        if #marks_of_line > 1 then
          for i = 2, #marks_of_line do
            vim.api.nvim_buf_del_extmark(self.buf_id, self.ext_marks_ns_id, marks_of_line[i][1])
          end
        end

        -- delete marks in lines without indentation
        local mark_line = vim.api.nvim_buf_get_lines(self.buf_id, mark_pos[1], mark_pos[1] + 1, false)
        local mark_line_has_indent_inside = vim.fn.match(mark_line[1], indent) > -1

        if (not mark_line_has_indent_inside) then
          vim.api.nvim_buf_del_extmark(self.buf_id, self.ext_marks_ns_id, mark_id)
        end
      end
    })

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
        local idx_adjusted = #indent + idx
        vim.api.nvim_buf_add_highlight(self.buf_id, self.highlight_ns_id, 'BroilSearchTerm', index - 1,
          idx_adjusted - 1,
          idx_adjusted)
      end
    end
  end

  -- conceal ids at end of the line
  vim.api.nvim_win_call(self.win_id, function()
    vim.fn.matchadd('Conceal', [[\[\d\+\]$]])
  end)
end

function Tree:render_name(bline)
  if (bline.parent_id == nil) then
    return bline.path
  end

  if (self.pattern ~= '') then
    return bline.relative_path
  end

  return bline.name
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

--- scrolls up via ctrl-u
function Tree:scroll_up()
  vim.api.nvim_win_call(self.win_id, function()
    local cursor = vim.api.nvim_win_get_cursor(self.win_id)
    local new_cursor_y = cursor[1] - vim.wo.scroll
    if new_cursor_y < 1 then
      new_cursor_y = 1
    end
    vim.api.nvim_win_set_cursor(self.win_id, { new_cursor_y, cursor[2] })
  end)
end

function Tree:scroll_down()
  vim.api.nvim_win_call(self.win_id, function()
    local cursor = vim.api.nvim_win_get_cursor(self.win_id)
    local new_cursor_y = cursor[1] + vim.wo.scroll
    local line_count = vim.api.nvim_buf_line_count(self.buf_id)
    if new_cursor_y > line_count then
      new_cursor_y = line_count
    end
    vim.api.nvim_win_set_cursor(self.win_id, { new_cursor_y, cursor[2] })
  end)
end

function Tree:scroll_top_node()
  vim.api.nvim_win_call(self.win_id, function()
    vim.cmd('normal! gg')
  end)
end

function Tree:scroll_end()
  vim.api.nvim_win_call(self.win_id, function()
    vim.cmd('normal! G')
  end)
end

--- @param bid broil.BId|nil bline.id
--- @return broil.BLine|nil
function Tree:find_by_id(bid)
  if bid == nil then
    return nil
  end

  local bline = nil
  for _, tree_bline in ipairs(self.lines) do
    if (tree_bline.id == bid) then
      bline = tree_bline
      break
    end
  end
  return bline
end

return Tree
