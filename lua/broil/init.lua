local broil = {}

local config = require("broil.config")
local ui = require("broil.ui")

broil.setup = function(opts)
  config.set(opts)
end

broil.open = function()
  ui.open_float()
end

return broil;
