local Tree_Builder = require('broil.tree_builder')
local Tree = require('broil.tree')
local fs = require('broil.fs')
local utils = require('broil.utils')
local Editor = require('broil.editor')

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
  search_term = "", -- current search filter,
  info_buf_id = nil,
  info_buf_default_msg = "Hit 'enter' to focus, '?' for help, or  ':<verb>' to execute a command",
  info_highlight_ns_id = vim.api.nvim_create_namespace('BroilInfoHighlights'),
  open_path = nil,
  open_history = {}, -- we can reset to this later
  editor = Editor:new(),
}

--- scan the file system at dir and create a tree view for the buffer
--- @param dir string root directory to create nodes from
ui.create_tree_window = function(dir)
  -- 1. create a tree buffer
  ui.buf_id = vim.api.nvim_create_buf(false, true)
  vim.b[ui.buf_id].modifiable = true
  vim.wo.signcolumn = 'yes'
  vim.api.nvim_set_option_value('tabstop', 3, { buf = ui.buf_id })
  vim.api.nvim_set_option_value('shiftwidth', 3, { buf = ui.buf_id })
  vim.api.nvim_set_option_value('expandtab', true, { buf = ui.buf_id })

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
      print("build edits...")
      ui.editor:handle_edits(ui.tree)

      print("edits", vim.inspect(ui.editor.current_edits))
    end
  })
end

ui.create_search_window = function()
  -- Create a buffer for the search window
  ui.search_buf_id = vim.api.nvim_create_buf(false, true)

  -- If a search window already exists, close it
  if (ui.search_win_id ~= nil) then
    vim.api.nvim_win_close(ui.search_win_id, true)
  end

  -- Create a split window with a specific height for the search window
  vim.api.nvim_command(1 .. 'split')
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

--- create the info bar at the top
ui.create_info_bar_window = function()
  ui.info_buf_id = vim.api.nvim_create_buf(false, true)

  local opts = {
    style = "minimal",
    relative = "win",
    win = ui.win_id,
    width = vim.o.columns,
    height = 1,
    row = vim.api.nvim_win_get_height(ui.win_id) - 2,
    col = 0,
  }

  ui.set_info_bar_message()
  ui.info_win_id = vim.api.nvim_open_win(ui.info_buf_id, false, opts)
end

--- @param msg string|nil
--- @param type 'verb'|nil
--- highlights everything in '' quotes
ui.set_info_bar_message = function(msg, type)
  if (not msg) then
    msg = ui.info_buf_default_msg
  end

  -- highlight everything in '' quotes
  vim.api.nvim_command('highlight BroilHelpCommand guifg=#b4befe')
  vim.api.nvim_command('syntax match BroilHelpCommand /\'[^\']*\'/')

  -- Set the buffer lines
  local icon = ' 󰙎 - ';
  if (type == 'verb') then
    icon = '  - ';
  end
  vim.api.nvim_buf_set_lines(ui.info_buf_id, 0, -1, false, { icon .. msg })

  -- Find and highlight each quoted string
  local start_pos = 1
  while true do
    -- Find the next quoted string
    local start_quote, end_quote = string.find(msg, "'[^']*'", start_pos)

    -- If no more quoted strings were found, break the loop
    if not start_quote then break end

    -- Adjust the positions for the prefix and the quotes themselves
    local highlight_start = start_quote + 8 -- 7 for ' 󰙎 - ' and 1 for the quote
    local highlight_end = end_quote + 8 - 1 -- 7 for ' 󰙎 - ' and -1 because the end position is inclusive

    -- Add the highlight
    vim.api.nvim_buf_add_highlight(ui.info_buf_id, -1, 'BroilHelpCommand', 0, highlight_start, highlight_end)

    -- Move to the next position
    start_pos = end_quote + 1
  end
end

--- Attaches Event Listener that gets called when the search input is changed
ui.on_search_input_listener = function()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = ui.search_buf_id,
    callback = function()
      local previous_search_term = ui.search_term
      local search_buf_text = vim.api.nvim_buf_get_lines(ui.search_buf_id, 0, -1, false)[1]

      -- split the search buf text at the first ':'colon
      local colon_pos = string.find(search_buf_text, ":")

      if colon_pos then
        ui.search_term = string.sub(search_buf_text, 1, colon_pos - 1)
        ui.set_verb(string.sub(search_buf_text, colon_pos + 1))
      else
        ui.search_term = search_buf_text
        ui.set_verb()
      end

      if (previous_search_term ~= ui.search_term) then
        utils.debounce(function()
          ui.render()
        end, 100)()
      end
    end
  })
end

--- Set the verb in the info bar
--- @param verb string|nil
ui.set_verb = function(verb)
  local replaced_verb_variables = verb
  if (replaced_verb_variables == nil) then
    ui.set_info_bar_message()
  elseif (replaced_verb_variables == "") then
    ui.set_info_bar_message("Type a " ..
      vim.o.shell .. " command to execute. '@' = 'selection_path', Hit 'enter' to execute it")
  else
    local tree_cursor = vim.api.nvim_win_get_cursor(ui.win_id)
    local cursor_line = vim.api.nvim_buf_get_lines(ui.buf_id, tree_cursor[1] - 1, tree_cursor[1], false)[1]

    local path_id = utils.get_bid_by_match(cursor_line)
    local bline = ui.tree:find_by_id(path_id)
    local root_node = ui.tree.lines[1]
    local bline_path = bline and bline.path or ""
    local bline_name = bline and bline.name or ""

    if (bline_path == "") then
      bline_path = root_node.path ..
          '/' ..
          cursor_line:gsub("^%s*", ""):gsub("%[%d+%]$", "") -- remove leading whitespace and pathid
    end

    if (bline_name == "") then
      bline_name = cursor_line:gsub("^%s*", ""):gsub("%[%d+%]$", "") -- remove leading whitespace and pathid
    end

    replaced_verb_variables = replaced_verb_variables:gsub("@", bline_path)
    replaced_verb_variables = replaced_verb_variables:gsub("%^", root_node.path)
    replaced_verb_variables = replaced_verb_variables:gsub("%%", bline_name)

    -- replace the verb path in the actual search buffer
    vim.api.nvim_buf_set_lines(ui.search_buf_id, 0, -1, false, { ui.search_term .. ':' .. replaced_verb_variables })
    vim.api.nvim_win_set_cursor(ui.search_win_id, { 1, #ui.search_term + #replaced_verb_variables + 2 })

    ui.set_info_bar_message(replaced_verb_variables, 'verb')
  end

  ui.verb = replaced_verb_variables
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

ui.scroll_up = function()
  if (not ui.tree) then
    return
  end

  ui.tree:scroll_up()
end

ui.scroll_down = function()
  if (not ui.tree) then
    return
  end

  ui.tree:scroll_down()
end

ui.scroll_top_node = function()
  if (not ui.tree) then
    return
  end

  ui.tree:scroll_top_node()
end

ui.scroll_end = function()
  if (not ui.tree) then
    return
  end

  ui.tree:scroll_end()
end

--- Opens the currently selected tree node (Tree.selected_render_index)
--- It enters the node if its a dir,
--- otherwise it opens the file in a new buffer
ui.open_selected_node_or_run_verb = function()
  -- if we have a verb, we execute it instead of opening the node
  if (ui.verb ~= '') then
    return ui.run_current_verb()
  end

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

ui.run_current_verb = function()
  -- open split above ui.win_id
  -- create a floating terminal window
  local term_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_open_win(term_buf_id, true, {
    relative = "win",
    width = vim.o.columns,
    height = vim.api.nvim_win_get_height(ui.win_id) + vim.api.nvim_win_get_height(ui.search_win_id) + 2,
    row = 0,
    col = 0,
    style = "minimal",
  })
  -- run the verb in the terminal
  vim.api.nvim_command('term ' .. ui.verb)

  -- rerender when the terminal is closed
  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    buffer = term_buf_id,
    callback = function()
      local win_cursor = vim.api.nvim_win_get_cursor(ui.win_id)
      ui.render(win_cursor[1])
    end
  })
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
  ui.create_info_bar_window()
  ui.create_search_window()

  -- focus the search window
  vim.api.nvim_set_current_win(ui.search_win_id)


  -- 4. attach event listeners
  ui.on_search_input_listener()
  ui.on_yank()
  ui.on_close_listener()

  local keymap = require('broil.keymap')
  keymap.attach();

  ui.render()
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

  if (ui.info_win_id ~= nil) then
    vim.api.nvim_win_close(ui.info_win_id, true)
    ui.info_win_id = nil
  end

  vim.api.nvim_command('stopinsert')
end

ui.on_close_listener = function()
  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    buffer = ui.buf_id,
    callback = function()
      ui.close()
    end
  })
  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    buffer = ui.info_buf_id,
    callback = function()
      ui.close()
    end
  })
  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    buffer = ui.search_buf_id,
    callback = function()
      ui.close()
    end
  })
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

--- @param selection_index number|nil line nr to select after the render. If nil, select the highest score
ui.render = function(selection_index)
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
  ui.tree:initial_selection(selection_index)
  builder:destroy()
end

return ui
