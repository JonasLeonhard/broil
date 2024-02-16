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
}

local dev_icons = require('nvim-web-devicons')
local config = require('broil.config')

local Tree = {
  buf_id = nil,
  selected_render_index = nil,
  nodes = {}
}

function Tree:Node(node_option)
  local node = {
    id = string.format('%s_%s', node_option.index, node_option.depth),
    parent_id = nil,
    path = node_option.path,
    type = node_option.type,
    index = node_option.index,
    render_index = nil, -- set before rendering the node
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

  local is_selected = self.selected_render_index == node.render_index

  local rendered_line = indent ..
      node.path ..
      ' ID: ' ..
      node.id ..
      ' ,Parent: ' ..
      node.parent_id ..
      ' ,index: ' .. node.index .. ' ,render_index: ' .. node.render_index .. ' ,is_selected: ' .. tostring(is_selected)

  if node.type == "directory" then
    rendered_line = rendered_line .. "/"
  end

  vim.api.nvim_buf_set_lines(ui.buf_id, render_index, render_index, false, { rendered_line })

  -- apply line highlights and icons as soon as the line rendered
  if rendered_line:find('/') then
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

  return rendered_line
end

--- render array of nodes recursively
function Tree:render(nodes, depth, current_line_index)
  local rendered_lines = 0

  for _, node in ipairs(nodes) do
    local render_index = (current_line_index or 0) + rendered_lines

    Tree:renderNode(node, render_index)
    rendered_lines = rendered_lines + 1

    -- render node children recursively
    if node.type == "directory" then
      rendered_lines = rendered_lines + self:render(node.children, (depth or 0) + 1, render_index + 1)
    end
  end

  return rendered_lines
end

-- TODO: implement
function Tree:filter(nodes, search_term)
  print(search_term)
  for i = 1, #search_term do
    local c = search_term:sub(i, i)
    print(c, string.byte(c))
  end

  if (search_term == 'lua') then
    print("in if", search_term)
    return { nodes[2] }
  end

  return nodes
end

ui.clear = function()
  vim.api.nvim_buf_set_lines(ui.buf_id, 0, -1, false, {})
end


--- scan the file system at dir and create a tree view for the buffer
ui.create_tree_and_render = function(dir)
  vim.wo.signcolumn = 'yes'
  local nodes = ui.create_nodes(dir, 0, 0)
  Tree.nodes = nodes
  ui.clear()
  Tree:render(nodes)
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
      local search_term = vim.api.nvim_buf_get_lines(ui.search_buf_id, 0, -1, false)[1]

      if (Tree.selected_render_index == nil) then
        Tree.selected_render_index = 0
      else
        Tree.selected_render_index = Tree.selected_render_index + 1
      end
      ui.clear()
      local filtered_nodes = Tree:filter(Tree.nodes, search_term)
      Tree:render(filtered_nodes)
    end
  })
end

ui.help = function()
  print("broil help")
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
  ui.float_win.title = " " .. file_dir .. "| [" .. ui.mode .. "]"

  ui.create_tree_and_render(file_dir)
  ui.win_id = vim.api.nvim_open_win(ui.buf_id, false, ui.float_win) -- Open a floating search_results window

  -- 2. create a search propmt at the bottom
  ui.search_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(ui.search_buf_id, 'textwidth', ui.search_win.width) -- Set text width to the width of the window
  ui.search_win_id = vim.api.nvim_open_win(ui.search_buf_id, true, ui.search_win) -- Open a floating focused search window


  -- 3. attach event listeners
  ui.on_edits_made_listener()
  ui.on_search_input_listener()
end

return ui
