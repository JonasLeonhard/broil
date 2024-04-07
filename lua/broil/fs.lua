local config = require('broil.config')
local Job = require('plenary.job')
local Filesystem = {}

function Filesystem:delete(path_from, callback)
  local job_out = {}

  Job:new({
    command = config.shell,
    args = { config.shell_exec_flag, config.rm_command:gsub('<FROM>', vim.fn.shellescape(path_from)) },
    cwd = vim.fn.getcwd(),
    on_stdout = function(_, stdout)
      table.insert(job_out, stdout)
    end,
    on_stderr = function(_, stderr)
      table.insert(job_out, stderr)
    end,
    on_exit = function(_, exit_code)
      callback(job_out, exit_code)
    end,
  }):start()
end

function Filesystem:move(path_from, path_to, callback)
  local job_out = {}

  Job:new({
    command = config.shell,
    args = { config.shell_exec_flag, config.mv_command:gsub('<FROM>', vim.fn.shellescape(path_from)):gsub('<TO>', vim.fn.shellescape(path_to)) },
    cwd = vim.fn.getcwd(),
    on_stdout = function(_, stdout)
      table.insert(job_out, stdout)
    end,
    on_stderr = function(_, stderr)
      table.insert(job_out, stderr)
    end,
    on_exit = function(_, exit_code)
      callback(job_out, exit_code)
    end,
  }):start()
end

function Filesystem:copy(path_from, path_to, callback)
  local job_out = {}

  Job:new({
    command = config.shell,
    args = { config.shell_exec_flag, config.cp_command:gsub('<FROM>', vim.fn.shellescape(path_from)):gsub('<TO>', vim.fn.shellescape(path_to)) },
    cwd = vim.fn.getcwd(),
    on_stdout = function(_, stdout)
      table.insert(job_out, stdout)
    end,
    on_stderr = function(_, stderr)
      table.insert(job_out, stderr)
    end,
    on_exit = function(_, exit_code)
      callback(job_out, exit_code)
    end,
  }):start()
end

function Filesystem:create(path_to, callback)
  local job_out = {}
  if (path_to:sub(-1) == '/') then
    Job:new({
      command = config.shell,
      args = { config.shell_exec_flag, config.mkdir_command:gsub('<TO>', vim.fn.shellescape(path_to)) },
      cwd = vim.fn.getcwd(),
      on_stdout = function(_, stdout)
        table.insert(job_out, stdout)
      end,
      on_stderr = function(_, stderr)
        table.insert(job_out, stderr)
      end,
      on_exit = function(_, exit_code)
        callback(job_out, exit_code)
      end,
    }):start()
  else
    Job:new({
      command = config.shell,
      args = { config.shell_exec_flag, config.touch_command:gsub('<TO>', vim.fn.shellescape(path_to)) },
      cwd = vim.fn.getcwd(),
      on_stdout = function(_, stdout)
        table.insert(job_out, stdout)
      end,
      on_stderr = function(_, stderr)
        table.insert(job_out, stderr)
      end,
      on_exit = function(_, exit_code)
        callback(job_out, exit_code)
      end,
    }):start()
  end
end

return Filesystem
