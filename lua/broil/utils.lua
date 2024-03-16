local utils = {}

local timer_ids = {}
function utils.debounce(debounce_id, fn, delay)
  return function(...)
    if timer_ids[debounce_id] then
      vim.loop.timer_stop(timer_ids[debounce_id])
      timer_ids[debounce_id] = nil
    end
    local args = { ... }
    timer_ids[debounce_id] = vim.defer_fn(function()
      fn(unpack(args))
    end, delay)
  end
end

--- @return broil.BId|nil bid id of the line "linetext[bid]"
function utils.get_bid_by_match(line)
  if (line == nil) then return nil end

  local id_str = line:match("%[(%d+)%]$")

  local ok, res = pcall(tonumber, id_str)
  if not ok then return nil end

  return res
end

--- remove special meaning from chars in a gsub string. Eg. the dot char.
--- replaces all non-alphanumeric characters with their escaped versions
function utils.escape_pattern(text)
  return text:gsub("([^%w])", "%%%1")
end

function utils.get_dir_of_file_dir(path)
  return vim.fn.fnamemodify(path, ':h')
end

return utils;
