local keymap = {}

local config = require('broil.config')
local filesystem = require('broil.fs')
local ui = require('broil.ui')

keymap.map = function(mode, lhs, rhs, opts)
  if lhs == '' then return end
  opts = vim.tbl_deep_extend('force', { buffer = ui.buf_id, silent = true, nowait = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

keymap.attach_to_float = function()
  keymap.map('n', config.mappings.synchronize, filesystem.synchronize, { desc = 'Synchronize' })
  keymap.map('n', config.mappings.help, ui.help, { desc = 'Synchronize' })
end

return keymap
