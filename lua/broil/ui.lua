local ui = {
  -- #State
  mode = "tree", -- tree or buffer
  -- #Content
  buf_id = nil,
  win_id = nil,
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
  -- #Search
  search_win_id = nil,
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
}

local config = require('broil.config')
local Tree = require('broil.tree')
local fs = require('broil.fs')
local utils = require('broil.utils')

--- scan the file system at dir and create a tree view for the buffer
--- @param dir string root directory to create nodes from
ui.create_tree_window = function(dir)
  -- 1. create a tree buffer
  ui.buf_id = vim.api.nvim_create_buf(false, true)
  vim.b[ui.buf_id].modifiable = true
  vim.wo.signcolumn = 'yes'

  -- -- 2. set the tree dir to the root path. TODO: search_input_listener called initially
  Tree.root_path = dir -- refactor
  -- Tree:build_and_render(dir, ui.search_term, config.special_paths, ui.buf_id, ui.win_id)

  -- 3. create a new tree buffer window
  if (ui.win_id ~= nil) then
    vim.api.nvim_win_close(ui.win_id, true)
  end
  ui.float_win.title = " " .. Tree.root_path .. "| [" .. ui.mode .. "]"
  ui.win_id = vim.api.nvim_open_win(ui.buf_id, false, ui.float_win)
end


--- Event Listener that gets called when edits are made to the tree buffer
ui.on_edits_made_listener = function()
  vim.api.nvim_buf_attach(ui.buf_id, false, {
    on_lines = function()
      -- Change the border of the floating window when changes are made to yellow
      vim.api.nvim_command('highlight BroilFloatBorder guifg=#f9e2af')
      vim.api.nvim_win_set_config(ui.win_id, ui.float_win)
    end
  })
end

--- Attaches Event Listener that gets called when the search input is changed
ui.on_search_input_listener = function()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = ui.search_buf_id,
    callback = function()
      ui.search_term = vim.api.nvim_buf_get_lines(ui.search_buf_id, 0, -1, false)[1]

      utils.debounce(function()
        Tree:build_and_render(Tree.root_path, ui.search_term, config.special_paths, ui.buf_id, ui.win_id)
      end, 100)()
    end
  })
end


--- Display a help message
ui.help = function()
  print("broil help")
end

--- Selects the node that is rendered at the next render_index
ui.select_next_node = function()
  local new_index = (Tree.selected_render_index or -1) + 1
  local lines = vim.api.nvim_buf_get_lines(ui.buf_id, 0, -1, false)

  if (new_index > #lines - 2) then
    Tree.selected_render_index = 0
  else
    Tree.selected_render_index = new_index
  end

  Tree:render_selection(ui.buf_id, ui.win_id)
end


--- Selects the node that is rendered at the previous render_index
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

  Tree:render_selection(ui.buf_id, ui.win_id)
end

--- Opens the currently selected tree node (Tree.selected_render_index)
--- It enters the node if its a dir,
--- otherwise it opens the file in a new buffer
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
    ui.create_tree_window(node.full_path)
  else
    ui.close_float()
    vim.api.nvim_command('edit ' .. node.full_path)
    vim.api.nvim_command('stopinsert')
  end
end

--- Open the parent dir of the currently opened tree_view -> vim.fn.fnamemodify(Tree.root_path, ":h")
ui.open_parent_dir = function()
  local parent_dir = vim.fn.fnamemodify(Tree.root_path, ":h")
  if (parent_dir) then
    ui.create_tree_window(parent_dir)
  end
end

--- open a floating window with a tree view of the current file's directory
ui.open_float = function()
  -- create a tree_window and render the tree to it
  local open_dir = fs.get_dir_of_current_window_or_nvim_cwd()
  ui.create_tree_window(open_dir)

  -- 3. create a search prompt at the bottom
  ui.create_search_window()


  -- 4. attach event listeners
  ui.on_edits_made_listener()
  ui.on_search_input_listener()

  local keymap = require('broil.keymap')
  keymap.attach();
end

ui.create_search_window = function()
  ui.search_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(ui.search_buf_id, 'textwidth', ui.search_win.width) -- Set text width to the width of the window
  ui.search_win_id = vim.api.nvim_open_win(ui.search_buf_id, true, ui.search_win) -- Open a floating focused search window
  vim.api.nvim_command('startinsert')
  ui.set_search("")
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

  Tree:destroy()
end

ui.set_search = function(search_term)
  ui.search_term = search_term
  vim.api.nvim_buf_set_lines(ui.search_buf_id, 0, -1, false, { search_term })
end

return ui
