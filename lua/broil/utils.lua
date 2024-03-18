local strings = require "plenary.strings"

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

--- @param path string
--- dirty binary check... there must be a better way to do this performantly.
--- checks if a file is binary by reading the first 1000 bytes of the file and
--- checking if any of those bytes represent a control character (a byte with a value less than 32 in ASCII).
--- Control characters are non-printable characters that are commonly found in binary files but rarely in text files.
--- The exceptions are the tab (ASCII 9), line feed (ASCII 10), and carriage return (ASCII 13) characters,
--- which are control characters that are commonly found in text files.
function utils.check_is_binary(path)
  -- check if extension should not be previewd. Eg bins or images
  local file = io.open(path, "rb")
  if (not file) then
    return
  end
  local bytes = file:read(1000)
  file:close()
  if (not bytes) then
    return
  end

  local is_binary = false
  for i = 1, #bytes do
    if bytes:byte(i) < 32 and bytes:byte(i) ~= 9 and bytes:byte(i) ~= 10 and bytes:byte(i) ~= 13 then
      is_binary = true
      break
    end
  end

  return is_binary
end

--- turns bytes of fs_stat.size to megabytes
--- @param bytes number
--- @return number
function utils.bytes_to_megabytes(bytes)
  if (not bytes) then return 0 end
  return bytes / math.pow(1024, 2)
end

utils.table_of_length_filled_with = function(n, val)
  local empty_lines = {}
  for _ = 1, n do
    table.insert(empty_lines, val)
  end
  return empty_lines
end

utils.set_preview_message = function(bufnr, winid, message, fillchar)
  fillchar = vim.F.if_nil(fillchar, "01")
  local height = vim.api.nvim_win_get_height(winid)
  local width = vim.api.nvim_win_get_width(winid)
  vim.api.nvim_buf_set_lines(
    bufnr,
    0,
    -1,
    false,
    utils.table_of_length_filled_with(height, table.concat(utils.table_of_length_filled_with(width, fillchar), ""))
  )
  local anon_ns = vim.api.nvim_create_namespace ""
  local padding = table.concat(utils.table_of_length_filled_with(#message + 4, " "), "")
  local lines = {
    padding,
    "  " .. message .. "  ",
    padding,
  }
  vim.api.nvim_buf_set_extmark(
    bufnr,
    anon_ns,
    0,
    0,
    { end_line = height, hl_group = "BroilPreviewMessageFillchar" }
  )
  local col = math.floor((width - strings.strdisplaywidth(lines[2])) / 2)
  for i, line in ipairs(lines) do
    vim.api.nvim_buf_set_extmark(
      bufnr,
      anon_ns,
      math.floor(height / 2) - 1 + i,
      0,
      { virt_text = { { line, "BroilPreviewMessage" } }, virt_text_pos = "overlay", virt_text_win_col = col }
    )
  end
end

return utils;
