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

  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.select_prev_node, ui.select_prev_node,
    { desc = 'Select next node' })

  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.open_selected_node, ui.open_selected_node,
    { desc = 'Open selected node' })

  keymap.map(ui.buf_id, { 'n', 'i' }, config.mappings.open_selected_node2, ui.open_selected_node,
    { desc = 'Open selected node' })
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.open_selected_node2, ui.open_selected_node,
    { desc = 'Open selected node' })

  keymap.map(ui.buf_id, { 'n', 'i' }, config.mappings.open_parent_dir, ui.open_parent_dir,
    { desc = 'Open parent dir' })
  keymap.map(ui.search_buf_id, { 'n', 'i' }, config.mappings.open_parent_dir, ui.open_parent_dir,
    { desc = 'Open parent dir' })

  keymap.map(ui.buf_id, { 'n' }, config.mappings.pop_history, ui.pop_history,
    { desc = 'Pop history item' })
  keymap.map(ui.search_buf_id, { 'n' }, config.mappings.pop_history, ui.pop_history,
    { desc = 'Pop history item' })

  -- internal
  keymap.map(ui.buf_id, { 'n' }, 'p', ui.paste)
end

return keymap
