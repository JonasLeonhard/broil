local config = require('broil.config')

local id_counter = 0;

local BLine = {
  id = 0,
}
BLine.__index = BLine

--- @param options broil.BLine
--- @return broil.BLine
function BLine:new(options)
  local bline = {}
  setmetatable(bline, BLine)

  bline.id = id_counter
  id_counter = id_counter + 1

  -- Iterate over all fields in options
  for k, v in pairs(options) do
    bline[k] = v
  end

  return bline
end

function BLine:can_enter()
  return self.file_type == "directory" and config.special_paths[self.name] ~= 'no-enter'
end

--- @param callback function -> callback({ name, type })
function BLine:read_dir(callback)
  local handle = vim.loop.fs_scandir(self.path)

  while handle do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end

    callback(name, type)
  end
end

return BLine
