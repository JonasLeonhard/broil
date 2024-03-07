local filesystem = {}

filesystem.synchronize = function()
  print("sync file system here!")
end

filesystem.get_path_of_current_window_or_nvim_cwd = function()
  -- Set the title of the floating window to the current file_dir or nvim root_dir
  local file_path = vim.fn.expand("%:p")
  if file_path == "" or file_path == nil then
    file_path = vim.fn.getcwd() or "root"
  end

  return file_path
end

return filesystem
