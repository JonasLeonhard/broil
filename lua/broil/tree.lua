local dev_icons = require('nvim-web-devicons')
local utils = require('broil.utils')

local Tree = {
  buf_id = nil,
  selected_render_index = nil,
  selection_ns_id = vim.api.nvim_create_namespace('BroilSelection'),
  root_path = nil,
  nodes = {},
  search_term = '',     -- used to filter_nodes
  search_term_ns_id = vim.api.nvim_create_namespace('BroilSearchTerm'),
  filtered_nodes = nil, -- table|nil
}

function Tree:Node(node_option)
  local node = {
    id = string.format('%s_%s', node_option.index, node_option.depth),
    parent_id = nil,
    full_path = node_option.full_path,
    relative_path = node_option.relative_path, -- relative from open dir
    path = node_option.path,                   -- file or dir name
    type = node_option.type,                   -- "file", "directory", "link", "fifo", "socket", "char", "block", "unknown"
    index = node_option.index,
    render_index = nil,                        -- set before rendering the node
    depth = node_option.depth,
    children = node_option.children or {}
  }

  if (node_option.parent_index) then
    node.parent_id = string.format('%s_%s', node_option.parent_index, node_option.depth - 1)
  end

  return node
end

--- render array of nodes recursively
--- @param buf_id number buffer_id to render the tree into
--- @param nodes table|nil nodes to render, if left empty the tree renders Tree.nodes set from Tree:build
--- @param depth number|nil current depth, this is used in the recursion of children nodes
--- @param current_line_index number|nil current inserted line index, thisi s used to insert children recursively
function Tree:render(buf_id, nodes, depth, current_line_index)
  local render_nodes = nodes
  if (depth == nil or depth == 0) then
    render_nodes = nodes or self.filtered_nodes or self.nodes
  end
  if not render_nodes then
    return 0
  end
  local rendered_lines = 0

  -- clear highlights
  vim.api.nvim_buf_clear_namespace(buf_id, self.search_term_ns_id, 0, -1)

  for _, node in ipairs(render_nodes) do
    local render_index = (current_line_index or 0) + rendered_lines

    self:render_node(buf_id, node, render_index)
    rendered_lines = rendered_lines + 1

    -- render node children recursively
    if node.type == "directory" then
      rendered_lines = rendered_lines +
          self:render(buf_id, node.children, (depth or 0) + 1, render_index + 1)
    end
  end

  return rendered_lines
end

function Tree:render_node(buf_id, node, render_index)
  local indent = string.rep("  ", node.depth)
  node.render_index = render_index;

  local render_path = node.path
  if (self.search_term ~= '') then
    render_path = node.relative_path
  end

  local rendered_line = indent .. render_path

  if node.type == "directory" then
    rendered_line = rendered_line .. "/"
  end

  vim.api.nvim_buf_set_lines(buf_id, render_index, render_index, false, { rendered_line })

  -- apply line highlights and icons as soon as the line rendered
  if rendered_line:match('/$') then
    -- Directories in blue + dir icon
    vim.api.nvim_command('highlight BroilDirLine guifg=#89b4fa')
    vim.api.nvim_buf_add_highlight(buf_id, -1, 'BroilDirLine', render_index, 0, -1)

    vim.fn.sign_define('Broil_dir', { text = '', texthl = 'Broil_dir' })
    vim.fn.sign_place(render_index + 1, '', 'Broil_dir', buf_id, { lnum = render_index + 1 })
    vim.api.nvim_command('highlight Broil_dir guifg=#89b4fa')
  else
    -- file icon and highlight color from nvim-web-devicons
    local line_filetype = rendered_line:match("%.([^%.]+)$")


    if (line_filetype) then
      line_filetype = line_filetype:gsub("%W", "_") -- This will replace any character that is not a letter or a digit with an underscore, ensuring that `line_filetype` is always a valid group name.
      local sign_id = 'Broil_' .. line_filetype
      local icon, color = dev_icons.get_icon_color(rendered_line, line_filetype, nil)
      vim.fn.sign_define(sign_id, { text = icon, texthl = sign_id })
      vim.fn.sign_place(render_index + 1, '', sign_id, buf_id, { lnum = render_index + 1 })
      vim.api.nvim_command('highlight ' .. sign_id .. ' guifg=' .. color)
    else
      vim.fn.sign_define('Broil_file', { text = '', texthl = 'Broil_file' })
      vim.fn.sign_place(render_index + 1, '', 'Broil_file', buf_id, { lnum = render_index + 1 })
    end
  end

  -- search filter highlighting
  local match_indices = utils.fuzzy_match(node.relative_path, self.search_term)
  if match_indices then
    vim.api.nvim_command('highlight BroilSearchTerm guifg=#f9e2af')
    for _, idx in ipairs(match_indices) do
      vim.api.nvim_buf_add_highlight(buf_id, self.search_term_ns_id, 'BroilSearchTerm', render_index, #indent + idx - 1,
        #indent + idx)
    end
  end

  return rendered_line
end

function Tree:render_selection(buf_id, win_id)
  if (self.selected_render_index) then
    vim.api.nvim_buf_clear_namespace(buf_id, self.selection_ns_id, 0, -1)
    vim.api.nvim_command('highlight BroilSelection guibg=#45475a')
    vim.api.nvim_buf_add_highlight(buf_id, self.selection_ns_id, 'BroilSelection', self.selected_render_index, 0, -1)

    -- Set the cursor to the selected line
    vim.api.nvim_win_set_cursor(win_id, { self.selected_render_index + 1, 0 })
    vim.api.nvim_command('normal! zz')
  end
end

--- return a new table of filtered nodes where node or an ancestor matches the path
function Tree:filter(search_term)
  self.search_term = search_term

  if self.search_term == "" then
    self.filtered_nodes = nil
    return
  end

  local function filter_nodes(node, path)
    -- Create a copy of the node without .children
    local new_node = {}
    for k, v in pairs(node) do
      if k ~= 'children' then
        new_node[k] = v
      end
    end

    -- Check if the current node or an ancestor matches the path
    local current_matched = utils.fuzzy_match(node.relative_path, path)

    -- Check the children nodes
    for _, child in ipairs(node.children) do
      local child_result = filter_nodes(child, path)
      if child_result then
        new_node.children = new_node.children or {}
        table.insert(new_node.children, child_result)
      end
    end

    -- If the node matches the path or has matching children, return it
    if new_node.children or current_matched then
      return new_node
    end
  end

  -- create a filter
  local filtered = {}
  for _, node in ipairs(self.nodes) do
    local node_result = filter_nodes(node, self.search_term)
    if node_result then
      table.insert(filtered, node_result)
    end
  end

  self.selected_render_index = nil -- TODO: select the node with the highest matching score
  self.filtered_nodes = filtered
  return filtered
end

--- recursively find a node by a key with value. in the following case the first node with render_index == 1
--- eg: Tree:find_by('render_index', 1)
function Tree:find_by(key, value)
  -- Recursive function to search in children nodes
  local function searchInNodes(nodes)
    for _, node in ipairs(nodes) do
      if node[key] == value then
        return node
      end
      local found = searchInNodes(node.children)
      if found then
        return found
      end
    end
  end

  return searchInNodes(self.filtered_nodes or self.nodes)
end

--- recursively build Tree.nodes for the tree view at the given dir. Also sets Tree.root_path, Tree.selected_render_index
--- @param dir string root directory to create nodes with children from
--- @param special_paths table table of paths that should be hidden, or not entered for child nodes. Eg { ['node_modules']: 'no-enter', ['.git']: 'no-enter', ['.DS_Store'] = 'hide']}
--- @param parent_node_index number|nil index of the parent node. This should normally only be set when this function gets called recursively.
--- @param depth number|nil current depth of the tree. This increases when called recursively.
--- @return table nodes Tree:Node[]
function Tree:build(dir, special_paths, parent_node_index, depth)
  if (depth == nil or depth == 0) then
    self.root_path = dir
    self.selected_render_index = nil
  end

  local nodes = {}

  local node_index = 0
  for path, type in vim.fs.dir(dir, { depth = 1 }) do
    local node = self:Node({
      index = node_index,
      parent_index = parent_node_index,
      depth = depth or 0,
      path = path,
      full_path = dir .. "/" .. path,
      relative_path = string.gsub(dir .. "/" .. path, self.root_path .. "/", ""),
      type = type,
      children = {}
    })

    if type == "directory" and special_paths[path] ~= 'no-enter' then
      node.children = self:build(dir .. "/" .. path, special_paths, node_index, (depth or 0) + 1)
    end

    if special_paths[path] ~= 'hide' then
      table.insert(nodes, node)
    end

    node_index = node_index + 1
  end

  self.nodes = nodes
  return nodes
end

return Tree
