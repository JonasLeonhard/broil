local keymap = {}

local config = require('broil.config')
local ui = require('broil.ui')
local utils = require('broil.utils')

keymap.map = function(buf_id, mode, lhs, rhs, opts)
  if lhs == '' then return end
  opts = vim.tbl_deep_extend('force', { buffer = buf_id, silent = true, nowait = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

keymap.attach = function()
  keymap.map(ui.buf_id, 'n', config.mappings.help, ui.help, { desc = 'Help' })

  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.close, ui.close, { desc = 'Close' })
  keymap.map(ui.buf_id, { 'n', 'i' }, config.mappings.close, ui.close, { desc = 'Close' })
  keymap.map(ui.buf_id, { 'n', 'v' }, '<C-w>q', ui.close, { desc = 'Close' })
  keymap.map(ui.search_buf_id, { 'n', 'v' }, '<C-w>q', ui.close, { desc = 'Close' })

  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.select_next_node, ui.select_next_node,
    { desc = 'Select next node' })
  keymap.map(ui.search_buf_id, { 'n' }, config.mappings.select_next_node_normal, ui.select_next_node,
    { desc = 'Select next node normal' })
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.select_prev_node, ui.select_prev_node,
    { desc = 'Select prev node' })
  keymap.map(ui.search_buf_id, { 'n' }, config.mappings.select_prev_node_normal, ui.select_prev_node,
    { desc = 'Select prev node normal' })
  keymap.map(ui.search_buf_id, { 'n', 'i' }, '<C-d>', ui.scroll_down)
  keymap.map(ui.search_buf_id, { 'n', 'i' }, '<C-u>', ui.scroll_up)
  keymap.map(ui.search_buf_id, { 'n' }, 'gg', ui.scroll_top_node)
  keymap.map(ui.search_buf_id, { 'n' }, 'G', ui.scroll_end)

  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.open_selected_node, ui.open_selected_node_or_run_verb,
    { desc = 'Open selected node' })

  keymap.map(ui.buf_id, { 'n', 'i' }, config.mappings.open_selected_node2, ui.open_selected_node_or_run_verb,
    { desc = 'Open selected node' })
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.open_selected_node2, function()
      ui.open_selected_node_or_run_verb(true)
    end,
    { desc = 'Open selected node' })

  keymap.map(ui.buf_id, { 'n', 'i' }, config.mappings.open_parent_dir, ui.open_parent_dir,
    { desc = 'Open parent dir' })
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.open_parent_dir, ui.open_parent_dir,
    { desc = 'Open parent dir' })

  keymap.map(ui.buf_id, { 'n', 'i' }, config.mappings.pop_history, ui.pop_history,
    { desc = 'Pop history item' })
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.pop_history, ui.pop_history,
    { desc = 'Pop history item' })

  keymap.map(ui.buf_id, { 'n', 'i' }, config.mappings.open_edits_float, ui.open_edits_float)
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.open_edits_float, ui.open_edits_float)

  -- internal
  keymap.map(ui.buf_id, { 'n' }, 'p', ui.paste)

  -- Editor
  keymap.map(ui.editor.buf_id, { 'n', 'i' }, config.mappings.close, ui.close_edits_float)
  keymap.map(ui.editor.buf_id, { 'n' }, config.mappings.stage_edit, function() ui.editor:stage_edit() end)
  keymap.map(ui.editor.buf_id, { 'v' }, config.mappings.stage_edit, function() ui.editor:stage_edit_range() end)
  keymap.map(ui.editor.buf_id, { 'n', 'v' }, config.mappings.stage_all_edits, function() ui.editor:stage_all_edits() end)
  keymap.map(ui.editor.buf_id, { 'n', 'v' }, config.mappings.stage_all_edits2, function() ui.editor:stage_all_edits() end)
  keymap.map(ui.editor.buf_id, { 'n' }, config.mappings.unstage_edit, function() ui.editor:unstage_edit() end)
  keymap.map(ui.editor.buf_id, { 'v' }, config.mappings.unstage_edit, function() ui.editor:unstage_edit_range() end)
  keymap.map(ui.editor.buf_id, { 'n', 'v' }, config.mappings.unstage_all_edits,
    function() ui.editor:unstage_all_edits() end)
  keymap.map(ui.editor.buf_id, { 'n' }, config.mappings.undo_edit, function()
    ui.editor:undo_edit()
    utils.debounce('undo_edit', function()
      ui.render()
    end, 100)()
  end)
  keymap.map(ui.editor.buf_id, { 'v' }, config.mappings.undo_edit, function()
    ui.editor:undo_edit_range()
    utils.debounce('undo_edit_range', function()
      ui.render()
    end, 100)()
  end)
  keymap.map(ui.editor.buf_id, { 'n', 'v' }, config.mappings.apply_staged_edits,
    function()
      ui.editor:apply_staged_edits(function()
        utils.debounce('apply_staged_edits', function()
          ui.render()
        end, 100)()
      end)
    end)

  -- Config
  keymap.map(ui.buf_id, { 'n', 'i' }, config.mappings.open_config_float, ui.open_config_float)
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.open_config_float, ui.open_config_float)
  keymap.map(config.buf_id, { 'n', 'i' }, config.mappings.close, ui.close_config_float)
  keymap.map(config.buf_id, { 'n', 'i' }, 'm', function()
    config:toggle_search_mode()
  end)
  keymap.map(config.buf_id, { 'n', 'i' }, 's', function()
    config:toggle_sort()
  end)
  keymap.map(config.buf_id, { 'n', 'i' }, 'o', function()
    config:toggle_sort_order()
  end)
  keymap.map(config.buf_id, { 'n', 'i' }, 'h', function()
    config:toggle_show_hidden()
  end)
  keymap.map(config.buf_id, { 'n', 'i' }, 'H', function()
    config:toggle_show_special_paths_hide()
  end)
  keymap.map(config.buf_id, { 'n', 'i' }, 'C', function()
    config:toggle_fuzzy_case_mode()
  end)
  keymap.map(config.buf_id, { 'n', 'i' }, 'F', function()
    config:toggle_match()
  end)
end

return keymap
