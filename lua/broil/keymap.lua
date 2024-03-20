local keymap = {}

local config = require('broil.config')
local filesystem = require('broil.fs')
local ui = require('broil.ui')

keymap.map = function(buf_id, mode, lhs, rhs, opts)
  if lhs == '' then return end
  opts = vim.tbl_deep_extend('force', { buffer = buf_id, silent = true, nowait = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

keymap.attach = function()
  keymap.map(ui.buf_id, { 'n', 'i' }, config.mappings.synchronize, filesystem.synchronize, { desc = 'Synchronize' })
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.synchronize, filesystem.synchronize,
    { desc = 'Synchronize' })
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
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.open_selected_node2, ui.open_selected_node_or_run_verb,
    { desc = 'Open selected node' })

  keymap.map(ui.buf_id, { 'n', 'i' }, config.mappings.open_parent_dir, ui.open_parent_dir,
    { desc = 'Open parent dir' })
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.open_parent_dir, ui.open_parent_dir,
    { desc = 'Open parent dir' })

  keymap.map(ui.buf_id, { 'n' }, config.mappings.pop_history, ui.pop_history,
    { desc = 'Pop history item' })
  keymap.map(ui.search_buf_id, { 'n' }, config.mappings.pop_history, ui.pop_history,
    { desc = 'Pop history item' })

  keymap.map(ui.buf_id, { 'n', 'i' }, config.mappings.open_edits_float, ui.open_edits_float)
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.open_edits_float, ui.open_edits_float)

  keymap.map(ui.editor.buf_id, { 'n', 'i' }, config.mappings.close, ui.close_edits_float)
  -- internal
  keymap.map(ui.buf_id, { 'n' }, 'p', ui.paste)
end

return keymap
