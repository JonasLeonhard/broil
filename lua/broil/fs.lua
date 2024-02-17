local filesystem = {}

filesystem.synchronize = function()
  print("sync file system here!")
end

filesystem.get_dir_of_current_window_or_nvim_cwd = function()
  -- Set the title of the floating window to the current file_dir or nvim root_dir
  local file_dir = vim.fn.expand("%:h")
  if file_dir == "" then
    file_dir = vim.fn.getcwd() or "root"
  end

  return file_dir
end

return filesystem
