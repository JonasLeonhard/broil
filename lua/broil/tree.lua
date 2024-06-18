local Tree = {}
Tree.__index = Tree

local webdevicons = require('nvim-web-devicons')
local utils = require('broil.utils')
local cache = require('broil.cache')
local config = require('broil.config')

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

  tree.mark_virt_text = {} -- index -> mark_text
  return tree
end

function Tree:render()
  vim.api.nvim_buf_set_lines(self.buf_id, 0, -1, false, {})
  vim.api.nvim_buf_clear_namespace(self.buf_id, self.ext_marks_ns_id, 0, -1)
  self.mark_virt_text = {}

  for index, bline in ipairs(self.lines) do
    if (not cache.render_cache[self.buf_id]) then
      cache.render_cache[self.buf_id] = {}
    end
    cache.render_cache[self.buf_id][tostring(bline.id)] = bline
    local rendered_line = self:render_name(bline)

    if (bline.file_type == 'directory') then
      rendered_line = rendered_line .. '/'
    end

    -- Remove newline characters from the rendered_line
    rendered_line = rendered_line:gsub('\n', '')

    -- render conceal ids
    local conceal_id = '[' .. bline.id .. ']'
    rendered_line = rendered_line .. conceal_id

    -- render indentation for icons, we dont draw the lines yet, as they get drawn in the editor
    local tree_lines_length = bline.depth * 3
    local file_icon_length = 3

    local indent = string.rep(' ', tree_lines_length) .. string.rep(' ', file_icon_length)
    rendered_line = indent .. rendered_line

    -- bline render info
    bline.rendered = rendered_line

    -- Render the line
    vim.api.nvim_buf_set_lines(self.buf_id, index - 1, index - 1, false, { rendered_line })

    -- Render relative path dir parts
    if (self.pattern ~= '' and bline.fzf_pos) then
      local end_dir
      if (bline.file_type == 'directory') then
        local without_id = rendered_line:gsub("%[(%d+)%]$", "")
        local without_trailing_slash = without_id:gsub("/$", "")
        end_dir = without_trailing_slash:find("/[^/]*$")
      else
        end_dir = rendered_line:find("/[^/]*$")
      end

      if end_dir then
        vim.api.nvim_buf_add_highlight(self.buf_id, self.highlight_ns_id, 'BroilRelativeLine', index - 1, 0, end_dir - 1)
      end
    end

    -- search filter highlighting
    if bline.fzf_pos then
      for _, idx in ipairs(bline.fzf_pos) do
        local idx_adjusted = #indent + idx
        vim.api.nvim_buf_add_highlight(self.buf_id, self.highlight_ns_id, 'BroilSearchTerm', index - 1,
          idx_adjusted - 1,
          idx_adjusted)
      end
    end
  end

  -- conceal ids at end of the line
  if (self.win_id) then
    vim.api.nvim_win_call(self.win_id, function()
      vim.fn.matchadd('Conceal', [[\[\d\+\]$]])  -- eg: [13]
      vim.fn.matchadd('Conceal', [[\[.\d\+\]$]]) -- eg: [+13]
    end)
  end
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

function Tree:render_icon(line)
  local line_without_whitespace = line:gsub("%s+", "")
  local line_without_path_id = line_without_whitespace:gsub("%[?.%d+%]$", "")

  local line_ends_with_slash = line_without_path_id:sub(-1) == '/'
  if (line_ends_with_slash) then
    return '', '#89b4fa', 'directory'
  end

  -- TODO: line ends with unlisted
  local line_ends_with_unlisted = line_without_path_id:match(".*unlisted$")
  if (line_ends_with_unlisted) then
    return '󱞃', '#a6adc8', 'pruning'
  end

  -- TODO: better way to handle file extensions?
  local file_extension = line_without_path_id:match("%.([^%.]+)$")
  if (file_extension) then
    file_extension = file_extension:gsub("%W", "_") -- This will replace any character that is not a letter or a digit with an underscore, ensuring that `line_filetype` is always a valid group name.
  end

  local icon, color = webdevicons.get_icon_color(line_without_path_id, file_extension)
  return icon, color, file_extension or 'unknown'
end

--- draw line icons and tree lines
function Tree:draw_line_extmarks(index, line, current_lines)
  if (line == nil) then
    return
  end

  -- remove existing extmarks on line
  local line_marks = vim.api.nvim_buf_get_extmarks(self.buf_id, self.ext_marks_ns_id, { index - 1, 0 },
    { index - 1, -1 }, {})
  for _, mark in ipairs(line_marks) do
    vim.api.nvim_buf_del_extmark(self.buf_id, self.ext_marks_ns_id, mark[1])
  end

  local whitespace_count_to_first_char = (line:find("%S") or #line + 1) - 1

  local line_below = current_lines[index + 1]
  local whitespace_count_to_first_char_below = 0
  if (line_below) then
    whitespace_count_to_first_char_below = (line_below:find("%S") or (#line_below + 1)) - 1
  end

  local has_same_indent_below = false

  for i = index + 1, #current_lines do
    local line_below_current = current_lines[i]
    local current_whitespace_count_to_first_char_below = (line_below_current:find("%S") or (#line_below_current + 1)) - 1
    if (current_whitespace_count_to_first_char_below < whitespace_count_to_first_char) then
      break
    end

    if (current_whitespace_count_to_first_char_below == whitespace_count_to_first_char) then
      has_same_indent_below = true
      break
    end
  end

  -- enough space to render lines and icon?
  if (whitespace_count_to_first_char < 3) then
    return
  end

  -- render tree_lines
  local tree_lines = ''
  local mark_text_above = self.mark_virt_text[index - 1]
  for i = 1, (whitespace_count_to_first_char - 3) do
    local above_char = vim.api.nvim_call_function('strcharpart', { mark_text_above, i - 1, 1 }) -- the actual utf8 char

    if (vim.tbl_contains({ '│', '├', '' }, above_char)) then
      tree_lines = tree_lines:gsub('─', ' '):gsub('├', '│') -- remove all previous - chars
      if (whitespace_count_to_first_char_below < whitespace_count_to_first_char) then
        tree_lines = tree_lines:gsub('└', '│')
        tree_lines = tree_lines .. '└'
      else
        if (has_same_indent_below) then
          tree_lines = tree_lines .. '├'
        else
          tree_lines = tree_lines:gsub('└', '│')
          tree_lines = tree_lines .. '└'
        end
      end
    else
      tree_lines = tree_lines .. '─'
    end
  end

  -- render icon
  local icon, color, file_extension = self:render_icon(line)
  local path_id = utils.get_bid_by_match(line)
  local bline = self:find_by_id(path_id)
  if (bline ~= nil) then
    bline.file_extension = file_extension
  end
  vim.api.nvim_command('highlight BroilTreeIcons_' .. file_extension .. ' guifg=' .. color) -- highlight Icon in color

  -- Render Icon highlights
  if (file_extension == 'directory') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.highlight_ns_id, 'BroilDirLine', index - 1, 0, -1)
  end

  if (file_extension == 'pruning') then
    vim.api.nvim_buf_add_highlight(self.buf_id, self.highlight_ns_id, 'BroilPruningLine', index - 1, 0, -1)
  end

  vim.api.nvim_buf_set_extmark(self.buf_id, self.ext_marks_ns_id, index - 1, 0, {
    virt_text = { { tree_lines, 'BroilTreeLines' }, { icon, 'BroilTreeIcons_' .. file_extension } },
    virt_text_pos = 'overlay',
    invalidate = true,
  })
  self.mark_virt_text[index] = tree_lines .. icon

  -- search_mode 1 == grep
  if (config.search_mode == 1 and bline and #bline.grep_results > 0) then
    local first_result = bline.grep_results[1]
    -- trim to max_length of 20
    local line_start = first_result.line:sub(1, first_result.column - 2):sub(-20)
    local line_highlight = first_result.line:sub(first_result.column - 1, first_result.column_end)
    local line_end = first_result.line:sub(first_result.column_end + 1):sub(1, 20)

    vim.api.nvim_buf_set_extmark(self.buf_id, self.ext_marks_ns_id, index - 1, 0, {
      virt_text = {
        { first_result.row .. ':' .. first_result.column .. '|x' .. #bline.grep_results, 'BroilInfo' },
        { '…' .. line_start, 'BroilInactive' },
        { line_highlight, 'BroilSearchTerm' },
        { line_end .. '…', 'BroilInactive' }
      },
      virt_text_pos = 'eol',
      invalidate = true,
    })
  end
end

--- @param selection_id number|nil the inistal index to select. Nil = select the highest score
function Tree:initial_selection(selection_id)
  if (self.pattern == '' and selection_id) then
    for index, bline in ipairs(self.lines) do
      if (bline.id == selection_id) then
      vim.api.nvim_win_set_cursor(self.win_id, { index, 0 })
      return
      end
    end
  end

  if (self.pattern ~= '') then
    pcall(vim.api.nvim_win_set_cursor, self.win_id, { self.highest_score_index, 0 })
  else -- open the path
    pcall(vim.api.nvim_win_set_cursor, self.win_id, { self.open_path_index, 0 })
  end
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

  return cache.render_cache[self.buf_id][tostring(bid)]
end

--- remove the dirs children recursively if we can find them
--- @param children_to_remove broil.BId[]
function Tree:remove_children(children_to_remove)
  local removal_queue = {}
  local fill_removal_queue
  fill_removal_queue = function(subchildren_to_remove)
    for _, child_id in ipairs(subchildren_to_remove) do
      local child_bline = self:find_by_id(child_id)
      if child_bline then
        table.insert(removal_queue, child_bline.id)
        if child_bline.children then
          fill_removal_queue(child_bline.children)
        end
      end
    end
  end

  fill_removal_queue(children_to_remove)

  -- Remove lines in reverse order to avoid changing indices of yet-to-be-removed lines
  local current_lines = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)
  while #removal_queue > 0 do
    local path_id = table.remove(removal_queue)
    for i = #current_lines, 1, -1 do
      local line = current_lines[i]
      local line_path_id = utils.get_bid_by_match(line)
      if line_path_id == path_id then
        vim.api.nvim_buf_set_lines(self.buf_id, i - 1, i, false, {})
        table.remove(current_lines, i)
      end
    end
  end
end

return Tree
