local ui = {
  buf_id = nil,
  win_id = nil,
  search_win_id = nil,
  search = "todo_current_search_term",
  mode = "tree", -- tree or buffer
  float_win = {
    relative = "editor",
    width = vim.o.columns,                     -- 100% width
    height = math.ceil(vim.o.lines * 0.6) - 1, -- 60% height
    col = 0,
    row = vim.o.lines,
    style = "minimal",
    title = "broil",
    border = {
      { "┌", "BroilFloatBorder" },
      { "─", "BroilFloatBorder" },
      { "┐", "BroilFloatBorder" },
      { "│", "BroilFloatBorder" },
      { "┘", "BroilFloatBorder" },
      { "─", "BroilFloatBorder" },
      { "└", "BroilFloatBorder" },
      { "│", "BroilFloatBorder" },
    },
    zindex = 50,
  },
  search_win = {
    relative = "editor",
    width = vim.o.columns, -- 100% width
    height = 1,            -- 60% height
    col = 0,
    row = vim.o.lines - 1,
    style = "minimal",
    zindex = 51,
  },
  search_term = "", -- current search filter
  selection_ns_id = vim.api.nvim_create_namespace('BroilSelection'),
  search_term_ns_id = vim.api.nvim_create_namespace('BroilSearchTerm'),
}

local dev_icons = require('nvim-web-devicons')
local config = require('broil.config')
local utils = require('broil.utils')

local Tree = {
  buf_id = nil,
  selected_render_index = nil,
  root_path = nil,
  nodes = {},
  rendered_nodes = {}
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

function Tree:renderNode(node, render_index)
  local indent = string.rep("  ", node.depth)
  node.render_index = render_index;

  local render_path = node.path
  if (ui.search_term ~= '') then
    render_path = node.relative_path
  end

  local rendered_line = indent .. render_path

  if node.type == "directory" then
    rendered_line = rendered_line .. "/"
  end

  vim.api.nvim_buf_set_lines(ui.buf_id, render_index, render_index, false, { rendered_line })

  -- apply line highlights and icons as soon as the line rendered
  if rendered_line:match('/$') then
    -- Directories in blue + dir icon
    vim.api.nvim_command('highlight BroilDirLine guifg=#89b4fa')
    vim.api.nvim_buf_add_highlight(ui.buf_id, -1, 'BroilDirLine', render_index, 0, -1)

    vim.fn.sign_define('Broil_dir', { text = '', texthl = 'Broil_dir' })
    vim.fn.sign_place(render_index + 1, '', 'Broil_dir', ui.buf_id, { lnum = render_index + 1 })
    vim.api.nvim_command('highlight Broil_dir guifg=#89b4fa')
  else
    -- file icon and highlight color from nvim-web-devicons
    local line_filetype = rendered_line:match("%.([^%.]+)$")


    if (line_filetype) then
      line_filetype = line_filetype:gsub("%W", "_") -- This will replace any character that is not a letter or a digit with an underscore, ensuring that `line_filetype` is always a valid group name.
      local sign_id = 'Broil_' .. line_filetype
      local icon, color = dev_icons.get_icon_color(rendered_line, line_filetype, nil)
      vim.fn.sign_define(sign_id, { text = icon, texthl = sign_id })
      vim.fn.sign_place(render_index + 1, '', sign_id, ui.buf_id, { lnum = render_index + 1 })
      vim.api.nvim_command('highlight ' .. sign_id .. ' guifg=' .. color)
    else
      vim.fn.sign_define('Broil_file', { text = '', texthl = 'Broil_file' })
      vim.fn.sign_place(render_index + 1, '', 'Broil_file', ui.buf_id, { lnum = render_index + 1 })
    end
  end

  -- seach_term highlight
  local match_indices = utils.fuzzy_match(node.relative_path, ui.search_term)
  if match_indices then
    vim.api.nvim_command('highlight BroilSearchTerm guifg=#f9e2af')
    vim.api.nvim_buf_clear_namespace(ui.buf_id, ui.search_term_ns_id, 0, -1)
    for _, idx in ipairs(match_indices) do
      vim.api.nvim_buf_add_highlight(ui.buf_id, ui.search_term_ns_id, 'BroilSearchTerm', render_index, #indent + idx - 1,
        #indent + idx)
    end
  end

  return rendered_line
end

function Tree:render_selection()
  if (Tree.selected_render_index) then
    vim.api.nvim_buf_clear_namespace(ui.buf_id, ui.selection_ns_id, 0, -1)
    vim.api.nvim_command('highlight BroilSelection guibg=#45475a')
    vim.api.nvim_buf_add_highlight(ui.buf_id, ui.selection_ns_id, 'BroilSelection', Tree.selected_render_index, 0, -1)

    -- Set the cursor to the selected line
    vim.api.nvim_win_set_cursor(ui.win_id, { Tree.selected_render_index + 1, 0 })
    vim.api.nvim_command('normal! zz')
  end
end

--- render array of nodes recursively
function Tree:render(nodes, depth, current_line_index)
  local rendered_lines = 0

  if not nodes then
    return 0
  end

  for _, node in ipairs(nodes) do
    local render_index = (current_line_index or 0) + rendered_lines

    Tree:renderNode(node, render_index)
    rendered_lines = rendered_lines + 1

    -- render node children recursively
    if node.type == "directory" then
      rendered_lines = rendered_lines + self:render(node.children, (depth or 0) + 1, render_index + 1)
    end
  end

  Tree:render_selection()

  return rendered_lines
end

function Tree:filter(nodes, search_term)
  if search_term == "" then
    return nodes
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
  for _, node in ipairs(nodes) do
    local node_result = filter_nodes(node, search_term)
    if node_result then
      table.insert(filtered, node_result)
    end
  end

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

  return searchInNodes(self.rendered_nodes)
end

ui.clear = function()
  vim.api.nvim_buf_set_lines(ui.buf_id, 0, -1, false, {})
end


--- scan the file system at dir and create a tree view for the buffer
ui.create_tree_and_render = function(dir)
  vim.wo.signcolumn = 'yes'
  Tree.root_path = dir
  local nodes = ui.create_nodes(dir, 0, 0)
  Tree.nodes = nodes
  ui.clear()
  Tree.selected_render_index = nil
  local filtered = Tree:filter(nodes, ui.search_term)
  Tree:render(filtered)
  Tree.rendered_nodes = filtered

  if (ui.win_id ~= nil) then
    vim.api.nvim_win_close(ui.win_id, true)
  end
  ui.float_win.title = " " .. Tree.root_path .. "| [" .. ui.mode .. "]"
  ui.win_id = vim.api.nvim_open_win(ui.buf_id, false, ui.float_win)
end

--- recursively create nodes for the tree view
ui.create_nodes = function(dir, parent_node_index, depth)
  local nodes = {}

  local node_index = 0
  for path, type in vim.fs.dir(dir, { depth = 1 }) do
    local node = Tree:Node({
      index = node_index,
      parent_index = parent_node_index,
      depth = depth,
      path = path,
      full_path = dir .. "/" .. path,
      relative_path = string.gsub(dir .. "/" .. path, Tree.root_path .. "/", ""),
      type = type,
      children = {}
    })

    if type == "directory" and config.special_paths[path] ~= 'no-enter' then
      node.children = ui.create_nodes(dir .. "/" .. path, node_index, depth + 1)
    end

    if config.special_paths[path] ~= 'hide' then
      table.insert(nodes, node)
    end

    node_index = node_index + 1
  end

  return nodes
end


ui.on_edits_made_listener = function()
  vim.api.nvim_buf_attach(ui.buf_id, false, {
    on_lines = function()
      -- Change the border of the floating window when changes are made to yellow
      vim.api.nvim_command('highlight BroilFloatBorder guifg=#f9e2af')
      vim.api.nvim_win_set_config(ui.win_id, ui.float_win)
    end
  })
end

ui.on_search_input_listener = function()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = ui.search_buf_id,
    callback = function()
      ui.search_term = vim.api.nvim_buf_get_lines(ui.search_buf_id, 0, -1, false)[1]
      ui.clear()
      local filtered_nodes = Tree:filter(Tree.nodes, ui.search_term)
      Tree.selected_render_index = nil -- TODO: select the node with the highest matching score
      Tree:render(filtered_nodes, 0, 0)
      Tree.rendered_nodes = filtered_nodes
    end
  })
end

ui.help = function()
  print("broil help")
end

ui.select_next_node = function()
  local new_index = (Tree.selected_render_index or -1) + 1
  local lines = vim.api.nvim_buf_get_lines(ui.buf_id, 0, -1, false)

  if (new_index > #lines - 2) then
    Tree.selected_render_index = 0
  else
    Tree.selected_render_index = new_index
  end

  Tree:render_selection()
end

ui.select_prev_node = function()
  local lines = vim.api.nvim_buf_get_lines(ui.buf_id, 0, -1, false)
  local new_index = (Tree.selected_render_index or #lines - 1) - 1

  if (new_index < 0) then
    local last_line_index = #lines - 2
    if (last_line_index < 0) then
      return
    end
    Tree.selected_render_index = last_line_index
  else
    Tree.selected_render_index = new_index
  end

  Tree:render_selection()
end

ui.open_selected_node = function()
  if (Tree.selected_render_index == nil) then
    return
  end

  local node = Tree:find_by('render_index', Tree.selected_render_index)

  if (node == nil) then
    return
  end

  if (node.type == "directory") then
    ui.set_search("")
    ui.create_tree_and_render(node.full_path)
  else
    ui.close_float()
    vim.api.nvim_command('edit ' .. node.full_path)
    vim.api.nvim_command('stopinsert')
  end
end

ui.open_parent_dir = function()
  local parent_dir = vim.fn.fnamemodify(Tree.root_path, ":h")
  ui.create_tree_and_render(parent_dir)
end

ui.set_keybinds = function()
  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'n', '<C-q>', '<cmd>lua require("broil.ui").close_float()<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'i', '<C-q>', '<cmd>lua require("broil.ui").close_float()<CR>',
    { noremap = true, silent = true })

  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'n', '<C-j>', '<cmd>lua require("broil.ui").select_next_node()<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'i', '<C-j>', '<cmd>lua require("broil.ui").select_next_node()<CR>',
    { noremap = true, silent = true })

  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'n', '<C-k>', '<cmd>lua require("broil.ui").select_prev_node()<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'i', '<C-k>', '<cmd>lua require("broil.ui").select_prev_node()<CR>',
    { noremap = true, silent = true })

  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'n', '<CR>', '<cmd>lua require("broil.ui").open_selected_node()<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'i', '<CR>', '<cmd>lua require("broil.ui").open_selected_node()<CR>',
    { noremap = true, silent = true })

  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'n', '<C-l>', '<cmd>lua require("broil.ui").open_selected_node()<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'i', '<C-l>', '<cmd>lua require("broil.ui").open_selected_node()<CR>',
    { noremap = true, silent = true })

  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'n', '<C-h>', '<cmd>lua require("broil.ui").open_parent_dir()<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(ui.search_buf_id, 'i', '<C-h>', '<cmd>lua require("broil.ui").open_parent_dir()<CR>',
    { noremap = true, silent = true })
end

--- open a floating window with a tree view of the current file's directory
ui.open_float = function()
  -- 1. create a search results buffer and window
  ui.buf_id = vim.api.nvim_create_buf(false, true)
  vim.b[ui.buf_id].modifiable = true

  -- Set the title of the floating window to the current file_dir or nvim root_dir
  local file_dir = vim.fn.expand("%:h")
  if file_dir == "" then
    file_dir = vim.fn.getcwd() or "root"
  end

  -- 2. render
  ui.create_tree_and_render(file_dir)

  -- 3. create a search prompt at the bottom
  ui.search_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(ui.search_buf_id, 'textwidth', ui.search_win.width) -- Set text width to the width of the window
  ui.search_win_id = vim.api.nvim_open_win(ui.search_buf_id, true, ui.search_win) -- Open a floating focused search window
  vim.api.nvim_command('startinsert')
  ui.set_search("")


  -- 4. attach event listeners
  ui.on_edits_made_listener()
  ui.on_search_input_listener()
  ui.set_keybinds()
end

ui.close_float = function()
  if (ui.win_id ~= nil) then
    vim.api.nvim_win_close(ui.win_id, true)
    ui.win_id = nil
  end

  if (ui.search_win_id ~= nil) then
    vim.api.nvim_win_close(ui.search_win_id, true)
    ui.search_win_id = nil
  end
end

ui.set_search = function(search_term)
  ui.search_term = search_term
  vim.api.nvim_buf_set_lines(ui.search_buf_id, 0, -1, false, { search_term })
end

return ui
