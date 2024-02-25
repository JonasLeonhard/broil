local dev_icons = require('nvim-web-devicons')
local async = require('plenary.async')
local Job = require('plenary.job')
local fzf = require('fzf_lib')

local Tree = {}

function Tree:new(dir, search_pattern, buf_id, win_id, max_lines)
  return {
    dirx = dir,
    search_pattern = search_pattern,
    test = function()
    end
  }
end

return Tree
