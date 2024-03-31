local broil = {}

local config = require("broil.config")
local ui = require("broil.ui")
local utils = require('broil.utils')

broil.setup = function(opts)
  -- DEBUG THE PERFORMANCE OF THE CREATED FLAMEGRAPH WITH: https://www.speedscope.app/
  vim.api.nvim_create_user_command("BroilProfileStart", function()
    require("plenary.profile").start(("profile-%s.log"):format(vim.version()), { flame = true })
  end, {})
  vim.api.nvim_create_user_command("BroilProfileStop", require("plenary.profile").stop, {})

  config.set(opts)

  -- highlights
  vim.api.nvim_command('highlight BroilPreviewMessageFillchar guifg=#585b70')
  vim.api.nvim_command('highlight BroilPreviewMessage guifg=#b4befe')
  vim.api.nvim_command('highlight BroilDeleted guifg=#f38ba8')
  vim.api.nvim_command('highlight BroilEdited guifg=#f9e2af')
  vim.api.nvim_command('highlight BroilAdded guifg=#a6e3a1')
  vim.api.nvim_command('highlight BroilSearchTerm guifg=#f9e2af')
  vim.api.nvim_command('highlight BroilDirLine guifg=#89b4fa')
  vim.api.nvim_command('highlight BroilPruningLine guifg=#a6adc8')
  vim.api.nvim_command('highlight BroilRelativeLine guifg=#74c7ec')
  vim.api.nvim_command('highlight BroilHelpCommand guifg=#b4befe')
  vim.api.nvim_command('highlight BroilEditorHeadline guifg=#cba6f7')
  vim.api.nvim_command('highlight BroilQueued guifg=#94e2d5')
  vim.api.nvim_command('highlight BroilInfo guifg=#b4befe')
  vim.api.nvim_command('highlight BroilInactive guifg=#a6adc8')
  vim.api.nvim_command('highlight BroilActive guifg=#f2cdcd')
  vim.api.nvim_command('highlight BroilSearchIcon guifg=#bac2de')
end

broil.open = function(path)
  if (path) then
    ui.open_path = path
  else
    ui.open_path = utils.get_path_of_current_window_or_nvim_cwd()
  end
  ui.open()
end

return broil;
