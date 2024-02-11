local ui = {
  buf_id = nil,
  win_id = nil,
  float_win = {
    relative = "editor",
    width = vim.o.columns,                 -- 100% width
    height = math.ceil(vim.o.lines * 0.6), -- 60% height
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
  }
}

local dev_icons = require('nvim-web-devicons')

local Tree = {
  buf_id = nil,
  nodes = {}
}

function Tree:Node(path, type, depth, children)
  return {
    path = path,
    type = type,
    depth = depth,
    children = children or {}
  }
end

function Tree:renderNode(node, render_index)
  local indent = string.rep("  ", node.depth)
  local rendered_line = indent .. node.path

  if node.type == "directory" then
    rendered_line = rendered_line .. "/"
  end

  vim.api.nvim_buf_set_lines(ui.buf_id, render_index, render_index, false, { rendered_line })

  -- apply line highlights and icons as soon as the line rendered
  if rendered_line:find('/') then
    -- Directories in blue + dir icon
    vim.api.nvim_command('highlight BroilDirLine guifg=#89b4fa')
    vim.api.nvim_buf_add_highlight(ui.buf_id, -1, 'BroilDirLine', render_index, 0, -1)

    vim.fn.sign_define('Broil_dir', { text = ' ', texthl = 'Broil_dir' })
    vim.fn.sign_place(render_index + 1, '', 'Broil_dir', ui.buf_id, { lnum = render_index + 1 })
    vim.api.nvim_command('highlight Broil_dir guifg=#89b4fa')
  else
    -- file icon and highlight color from nvim-web-devicons
    local line_filetype = rendered_line:match("^.+%.(.+)$")

    local sign_id = 'Broil_' .. line_filetype
    local icon, color = dev_icons.get_icon_color(rendered_line, line_filetype, nil)
    vim.fn.sign_define(sign_id, { text = icon, texthl = sign_id })
    vim.fn.sign_place(render_index + 1, '', sign_id, ui.buf_id, { lnum = render_index + 1 })
    vim.api.nvim_command('highlight ' .. sign_id .. ' guifg=' .. color)
  end

  return rendered_line
end

--- render array of nodes recursively
function Tree:render(nodes, depth, current_line_index)
  local rendered_lines = 0

  for _, node in ipairs(nodes) do
    local render_index = current_line_index + rendered_lines

    Tree:renderNode(node, render_index)
    rendered_lines = rendered_lines + 1

    -- render node children recursively
    if node.type == "directory" then
      rendered_lines = rendered_lines + self:render(node.children, depth + 1, render_index + 1)
    end
  end

  return rendered_lines
end

--- scan the file system at dir and create a tree view for the buffer
ui.render_tree = function(dir)
  vim.wo.signcolumn = 'yes'
  local nodes = ui.create_nodes(dir, 0)
  Tree:render(nodes, 0, 0)
end

--- recursively create nodes for the tree view
ui.create_nodes = function(dir, depth)
  local nodes = {}

  for path, type in vim.fs.dir(dir, { depth = 1 }) do
    local node = Tree:Node(path, type, depth, {})

    if type == "directory" then
      node.children = ui.create_nodes(dir .. "/" .. path, depth + 1)
    end

    table.insert(nodes, node)
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

ui.help = function()
  print("broil help")
end

--- open a floating window with a tree view of the current file's directory
ui.open_float = function()
  -- create a modifiable buffer
  ui.buf_id = vim.api.nvim_create_buf(false, true)
  vim.b[ui.buf_id].modifiable = true

  -- Set the title of the floating window to the current file_dir or nvim root_dir
  local file_dir = vim.fn.expand("%:h")
  if file_dir == "" then
    file_dir = vim.fn.getcwd() or "root"
  end
  ui.float_win.title = file_dir

  ui.render_tree(file_dir)
  ui.win_id = vim.api.nvim_open_win(ui.buf_id, true, ui.float_win) -- Open a focused floating window

  -- attach event listeners
  ui.on_edits_made_listener()
end

return ui
