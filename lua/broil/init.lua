local broil = {}

local config = require("broil.config")
local keymap = require("broil.keymap")
local ui = require("broil.ui")

broil.setup = function(opts)
  config.set(opts)
end

broil.open = function()
  ui.open_float()
  keymap.attach_to_float()
end

return broil;
