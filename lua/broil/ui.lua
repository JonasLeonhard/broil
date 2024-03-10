local ui = {
  -- #State
  mode = "tree", -- tree or buffer
  -- #Content
  buf_id = nil,
  win_id = nil,
  tree_win = {
    height = math.ceil(vim.o.lines * 0.6) - 1, -- 60% height
  },
  -- #Search
  search_win_id = nil,
  search_win = {
    height = 1,     -- 1line height
  },
  search_term = "", -- current search filter,
  open_path = nil,
  open_history = {} -- we can reset to this later
}

local Tree_Builder = require('broil.tree_builder')
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

  -- 2. create a new tree buffer window
  if (ui.win_id ~= nil) then
    vim.api.nvim_win_close(ui.win_id, true)
  end

  ui.open_path = dir

  -- Create a split window with a specific height
  vim.api.nvim_command(ui.tree_win.height .. 'split')
  ui.win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(ui.win_id, ui.buf_id)
  vim.wo[ui.win_id].conceallevel = 3

  -- build edits: todo, only call this after actual changes, not when the tree rerenders...
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = ui.buf_id,
    callback = function()
      local current_lines = vim.api.nvim_buf_get_lines(ui.buf_id, 0, -1, false)
      local edits = {}

      -- build line_changes and new lines
      for index, line in ipairs(current_lines) do
        local path_id = utils.get_bid_by_match(line)
        local bline = ui.tree:find_by_id(path_id)

        local path_from = nil
        local path_to = nil

        if (bline) then
          -- we edited a line with a blineid
          path_from = bline.path

          local path_head = vim.fn.fnamemodify(bline.path, ':h') or ''
          -- remove leading whitespace before first char, remove path_id from the end, remove relative path
          local edited_line = line:gsub("^%s*", ""):gsub("%[%d+%]$", "")
          local edited_line_name = vim.fn.fnamemodify(edited_line, ':t')

          if (edited_line_name ~= "") then
            path_to = path_head .. '/' .. edited_line_name
          end
        else
          -- we edited a line without a blineid
          --
          -- we probably want to get the path by iterating backwards from this line in the tree, until we hit a line with a parsable bid?
          -- path_to = '/new/path'
        end

        if (path_from ~= path_to) then
          local id = ('New:' .. index)
          if (path_id) then
            id = ('Bline:' .. path_id)
          end
          edits[id] = {
            path_from = path_from,
            path_to = path_to,
          }
        end

        print("edits", vim.inspect(edits))

        -- if (bline)then
        -- the
        -- local path_to = vim.fn.fnamemodify(bline.path, ':t')
        --     print("bline with id:", bline)
      end
    end
  })
end

ui.create_search_window = function()
  -- Create a buffer for the search window
  ui.search_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(ui.search_buf_id, 'textwidth', ui.search_win.width)

  -- If a search window already exists, close it
  if (ui.search_win_id ~= nil) then
    vim.api.nvim_win_close(ui.search_win_id, true)
  end

  -- Create a split window with a specific height for the search window
  vim.api.nvim_command(ui.search_win.height .. 'split')
  ui.search_win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(ui.search_win_id, ui.search_buf_id)

  -- Start insert mode in the new search window
  vim.api.nvim_command('startinsert')

  -- Set the initial search term
  ui.set_search("")

  -- Set the extmark at the beginning of the buffer and styling
  vim.api.nvim_create_namespace('BroilSearchIcon')
  vim.api.nvim_command('sign define BroilSearchIcon text=󰥨 ')
  vim.api.nvim_command('sign place 1 line=1 name=BroilSearchIcon buffer=' .. ui.search_buf_id)
  vim.api.nvim_command('setlocal nonumber')
  vim.api.nvim_command('setlocal norelativenumber')
end

--- Attaches Event Listener that gets called when the search input is changed
ui.on_search_input_listener = function()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = ui.search_buf_id,
    callback = function()
      ui.search_term = vim.api.nvim_buf_get_lines(ui.search_buf_id, 0, -1, false)[1]

      utils.debounce(function()
        ui.render()
      end, 100)()
    end
  })
end


--- Display a help message
ui.help = function()
  print("broil help")
end

ui.select_next_node = function()
  if (not ui.tree) then
    return
  end
  ui.tree:select_next()
end


ui.select_prev_node = function()
  if (not ui.tree) then
    return
  end
  ui.tree:select_prev()
end

--- Opens the currently selected tree node (Tree.selected_render_index)
--- It enters the node if its a dir,
--- otherwise it opens the file in a new buffer
ui.open_selected_node = function()
  local cursor_pos = vim.api.nvim_win_get_cursor(ui.win_id)
  local cursor_y = cursor_pos[1]

  if (not ui.tree or cursor_y == 1) then
    return
  end

  local node = ui.tree.lines[cursor_y]

  if (not node) then
    return
  end

  if (node.file_type == "directory") then
    ui.open_path = node.path
    ui.set_search("")
    ui.render()
  else
    ui.close()
    vim.api.nvim_command('edit ' .. node.path)
    vim.api.nvim_command('stopinsert')
  end
end

--- Open the parent dir of the currently opened tree_view -> vim.fn.fnamemodify(Tree.root_path, ":h")
ui.open_parent_dir = function()
  if (not ui.tree) then
    return
  end

  local node = ui.tree.lines[1]

  if (not node) then
    return
  end

  local parent_dir = vim.fn.fnamemodify(node.path, ":h")

  if (parent_dir) then
    ui.open_path = parent_dir
    ui.render()
  end
end

--- open a floating window with a tree view of the current file's directory
ui.open = function()
  -- 1. create a search prompt at the bottom
  ui.create_tree_window(fs.get_path_of_current_window_or_nvim_cwd())
  ui.create_search_window()


  -- 4. attach event listeners
  ui.on_search_input_listener()
  ui.on_yank()

  local keymap = require('broil.keymap')
  keymap.attach();
end

ui.close = function()
  if (ui.win_id ~= nil) then
    vim.api.nvim_win_close(ui.win_id, true)
    ui.win_id = nil
  end

  if (ui.search_win_id ~= nil) then
    vim.api.nvim_win_close(ui.search_win_id, true)
    ui.search_win_id = nil
  end
  vim.api.nvim_command('stopinsert')
end

ui.pop_history = function()
  if (#ui.open_history > 1) then
    table.remove(ui.open_history, #ui.open_history)
    local path_before = ui.open_history[#ui.open_history]
    ui.open_path = path_before
    ui.render()
  end
end

--- if a yanked line has a blineId [id], we only copy the bline name and id,
--- this prevents us from copying relative_paths when searching
ui.on_yank = function()
  vim.api.nvim_create_autocmd({ "TextYankPost" }, {
    buffer = ui.buf_id,
    callback = function()
      local event = vim.v.event
      local yanked_text = event.regcontents

      for i, line in ipairs(yanked_text) do
        local path_id = utils.get_bid_by_match(line)

        -- change the yanked text if we yanked a bline
        if (path_id) then
          local bline = ui.tree:find_by_id(path_id)
          if (bline) then
            yanked_text[i] = bline.name .. '[' .. bline.id .. ']'
          end
        end
      end

      -- Now set the yank register to the processed text
      vim.fn.setreg(event.regname, yanked_text, event.regtype)
    end
  })
end

-- we override the native paste functionality, because we strip out relative paths on yank
ui.paste = function()
  vim.api.nvim_command('normal! ""p')
end

ui.set_search = function(search_term)
  ui.search_term = search_term
  vim.api.nvim_buf_set_lines(ui.search_buf_id, 0, -1, false, { search_term })
end

ui.render = function()
  if (not ui.open_path) then
    ui.open_path = fs.get_path_of_current_window_or_nvim_cwd()
  end

  if (ui.open_history[#ui.open_history] ~= ui.open_path) then -- add the path to the history if its not the same
    table.insert(ui.open_history, ui.open_path)
  end

  local builder = Tree_Builder:new(ui.open_path, {
    pattern = ui.search_term,
    optimal_lines = ui.tree_win.height
  })
  local tree_build = builder:build_tree()
  ui.tree = Tree:new({
    pattern = ui.search_term,
    buf_id = ui.buf_id,
    win_id = ui.win_id,
    lines = tree_build.lines,
    highest_score_index = tree_build.highest_score_index,
    open_path_index = tree_build.open_path_index,
  })
  ui.tree:render()
  ui.tree:initial_selection()
  builder:destroy()
end

return ui
