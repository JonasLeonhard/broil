local utils = {}

function utils.debounce(fn, delay)
  local timer_id = nil
  return function(...)
    if timer_id then
      vim.loop.timer_stop(timer_id)
      timer_id = nil
    end
    local args = { ... }
    timer_id = vim.defer_fn(function()
      fn(unpack(args))
    end, delay)
  end
end

return utils;
