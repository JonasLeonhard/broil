local dev_icons = require('nvim-web-devicons')
local async = require('plenary.async')
local Job = require('plenary.job')
local fzf = require('fzf_lib')

local Tree = {
  buf_id = nil,
  selected_render_index = nil,
  selection_ns_id = vim.api.nvim_create_namespace('BroilSelection'),
  root_path = nil,
  nodes = {},
  search_pattern = '',  -- used to filter_nodes
  search_term_ns_id = vim.api.nvim_create_namespace('BroilSearchTerm'),
  filtered_nodes = nil, -- table|nil

  -- fzf
  job = nil,
  fzf_slab = nil,
  fzf_pattern_obj = nil,
  fzf_highest_score = nil
}

function Tree:Node(node_option)
  local node = {
    full_path = node_option.full_path,
    relative_path = node_option.relative_path, -- relative from open dir
    path = node_option.path,                   -- file or dir name
    type = node_option.type,                   -- "file", "directory", "link", "fifo", "socket", "char", "block", "unknown"
    index = node_option.index,
    render_index = nil,                        -- set before rendering the node
    depth = node_option.depth,
    children = node_option.children or {},
    fzf_score = nil,
    fzf_pos = nil
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
function Tree:render_nodes(buf_id, nodes, depth, current_line_index)
  local render_nodes = nodes
  if (depth == nil or depth == 0) then
    render_nodes = nodes or self.filtered_nodes or self.nodes
  end
  if not render_nodes then
    return 0
  end
  local rendered_lines = 0

  for _, node in ipairs(render_nodes) do
    local render_index = (current_line_index or 0) + rendered_lines

    self:render_node(buf_id, node, render_index)
    rendered_lines = rendered_lines + 1

    -- render node children recursively
    if node.type == "directory" then
      rendered_lines = rendered_lines +
          self:render_nodes(buf_id, node.children, (depth or 0) + 1, render_index + 1)
    end
  end

  return rendered_lines
end

function Tree:render_node(buf_id, node, render_index)
  local indent = string.rep("  ", node.depth)
  node.render_index = render_index;

  local render_path = node.path
  if (self.search_pattern ~= '') then
    render_path = node.relative_path
  end

  local rendered_line = indent .. render_path

  if node.type == "directory" then
    rendered_line = rendered_line .. "/"
  end

  if (self.fzf_pattern_obj and self.fzf_slab) then
    node.fzf_score = fzf.get_score(node.relative_path, self.fzf_pattern_obj, self.fzf_slab)
    node.fzf_pos = fzf.get_pos(node.relative_path, self.fzf_pattern_obj, self.fzf_slab)

    if (not self.fzf_highest_score or node.fzf_score > self.fzf_highest_score) then
      self.fzf_highest_score = node.fzf_score
      self.selected_render_index = node.render_index
    end
  end

  -- render line & highlight
  vim.schedule(function()
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

    if node.fzf_pos then
      vim.api.nvim_command('highlight BroilSearchTerm guifg=#f9e2af')
      for _, idx in ipairs(node.fzf_pos) do
        vim.api.nvim_buf_add_highlight(buf_id, self.search_term_ns_id, 'BroilSearchTerm', render_index, #indent + idx - 1,
          #indent + idx)
      end
    end
  end)

  return rendered_line
end

function Tree:render_selection(buf_id, win_id)
  if (self.selected_render_index) then
    vim.schedule(function()
      -- reset the render index if out of bounds
      local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
      if (self.selected_render_index > #lines - 1) then
        self.selected_render_index = #lines - 1
      end

      vim.api.nvim_buf_clear_namespace(buf_id, self.selection_ns_id, 0, -1)
      vim.api.nvim_command('highlight BroilSelection guibg=#45475a')
      vim.api.nvim_buf_add_highlight(buf_id, self.selection_ns_id, 'BroilSelection', self.selected_render_index, 0, -1)

      -- Set the cursor to the selected line and scroll to it
      vim.api.nvim_win_set_cursor(win_id, { self.selected_render_index + 1, 0 })
    end)
  end
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
--- @param search_pattern string seach pattern regex to filter nodes by
--- @param special_paths table table of paths that should be hidden, or not entered for child nodes. Eg { ['node_modules']: 'no-enter', ['.git']: 'no-enter', ['.DS_Store'] = 'hide']}
--- @param buf_id number buffer_id to render the tree into
--- @param win_id number win_id to render the tree into
function Tree:build_and_render(dir, search_pattern, special_paths, buf_id, win_id, max_lines)
  self.root_path = dir
  self.search_pattern = search_pattern

  -- init fuzzy finder
  self.fzf_slab = fzf.allocate_slab()
  self.fzf_pattern_obj = fzf.parse_pattern(self.search_pattern, 0, true)
  self.fzf_highest_score = nil

  local path_to_node_map = {}
  local nodes = {} -- build in add_nodes_from_path

  --- split the relative path of the full_path into parts and add a node for each part if one doesnt exist
  --- eg. for '/Users/someuser/some/path/' opened in self.root_path '/Users/someuser' it will add nodes for { some, some/path }
  --- @param full_path string eg: /Users/someuser/some/path/
  local add_nodes_from_path = function(full_path)
    local relative_path_parts = vim.split(full_path, "/")
    if (full_path:match('/$')) then
      table.remove(relative_path_parts, #relative_path_parts)
    end

    local build_relative_path = ''
    -- iterate the relative paths part
    -- eg iterations for '/some/path' -> 1: '/some', 2. '/some/path'
    -- create a node if one doesnt exist a '/some'
    for depth, path_part in ipairs(relative_path_parts) do
      local parent_node   = path_to_node_map[build_relative_path]
      build_relative_path = build_relative_path .. '/' .. path_part
      local node          = path_to_node_map[build_relative_path]

      -- dont render the node if its hidden
      if (special_paths[path_part] == 'hide') then
        break
      end

      if (not node) then
        local path_part_full_path = self.root_path .. build_relative_path
        local fs_stat = vim.loop.fs_stat(path_part_full_path)
        local type = fs_stat and fs_stat.type or 'file'

        node = self:Node({
          depth = depth,
          path = path_part,
          full_path = path_part_full_path,
          relative_path = build_relative_path,
          type = type,
          children = {}
        })
        path_to_node_map[build_relative_path] = node

        -- add this as a root node at depth 1, otherwise add it to the parent_nodes children
        if (depth == 1) then
          table.insert(nodes, node)
        else
          if (parent_node) then
            table.insert(parent_node.children, node)
          end
        end
      end

      -- dont enter more nodes in the path if no-enter is set
      if (special_paths[path_part] == 'no-enter') then
        break
      end
    end
  end

  --- @param files table paths table { '/some/path', '/some/other/path.lua' }
  local build_nodes = function(files)
    for _, full_path in ipairs(files) do
      add_nodes_from_path(full_path)
    end

    self.nodes = nodes
  end

  async.run(function()
    if (self.job and not self.job.is_shutdown) then
      self.job:shutdown()
    end

    local fd_args = { self.search_pattern, '-c', 'never', '--max-results', max_lines }
    self.job = Job:new({
      command = 'fd',
      args = fd_args,
      cwd = dir,
      on_exit = function(j, return_val)
        if (return_val ~= 0) then
          return
        end
        -- clear draw
        vim.schedule(function()
          vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, {})                    -- clear screen
          vim.api.nvim_buf_clear_namespace(buf_id, self.search_term_ns_id, 0, -1) -- last render highlights
        end)

        build_nodes(j:result())
        self:render_nodes(buf_id, nodes)
        self:render_selection(buf_id, win_id)
      end,
    })
    self.job:sync()
  end)
end

--- Free fzf related memory.
function Tree:destroy()
  if (self.fzf_pattern_obj) then
    fzf.free_pattern(self.fzf_pattern_obj)
  end

  if (self.fzf_slab) then
    fzf.free_slab(self.fzf_slab)
  end
end

return Tree
