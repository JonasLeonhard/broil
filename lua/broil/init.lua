local broil = {}

local config = require("broil.config")
local ui = require("broil.ui")

broil.setup = function(opts)
  -- DEBUG THE PERFORMANCE OF THE CREATED FLAMEGRAPH WITH: https://www.speedscope.app/
  vim.api.nvim_create_user_command("BroilProfileStart", function()
    require("plenary.profile").start(("profile-%s.log"):format(vim.version()), { flame = true })
  end, {})
  vim.api.nvim_create_user_command("BroilProfileStop", require("plenary.profile").stop, {})

  config.set(opts)
end

broil.open = function()
  ui.open()
end

return broil;
