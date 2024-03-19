local config = require('broil.config')
local cache = require('broil.cache')
local async = require('plenary.async')

local id_counter = 0;

local BLine = {}
BLine.__index = BLine

--- @param options broil.BLine
--- @return broil.BLine
function BLine:new(options)
  local bline = {}
  setmetatable(bline, BLine)

  -- Iterate over all fields in options
  for k, v in pairs(options) do
    bline[k] = v
  end

  -- return the cached node id if it already exist, cache it otherwise
  if (cache.bline_id_cache[options.path]) then
    bline.id = cache.bline_id_cache[options.path]
  else
    bline.id = id_counter
    cache.bline_id_cache[options.path] = id_counter
    id_counter = id_counter + 1
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
    async.util.scheduler() -- yield to scheduler to prevent blocking
    if not name then
      break
    end

    callback(name, type)
  end
end

--- @return string path of the dir. If the bline is a dir, return the dir path, if its a file, return the dir of the file
function BLine:get_dir_path()
  if (self.file_type == "directory") then
    return self.path
  end

  return vim.fn.fnamemodify(self.path, ":p:h")
end

return BLine
