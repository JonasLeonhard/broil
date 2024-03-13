local utils = require('broil.utils')

local Editor = {}
Editor.__index = Editor

--- @return broil.Editor
function Editor:new()
  local editor = {}
  setmetatable(editor, Editor)

  self.edits = {}         -- global edits stored between rerenders
  self.current_edits = {} -- edits local to a displayed tree, recalculated after each rerender

  return editor
end

function Editor:build_current_edits(tree)
  self.current_edits = {}
  local current_lines = vim.api.nvim_buf_get_lines(tree.buf_id, 0, -1, false)

  -- build line_changes and new lines
  for index, line in ipairs(current_lines) do
    if (line ~= '') then -- ignore emtpy lines
      local path_id = utils.get_bid_by_match(line)
      local bline = tree:find_by_id(path_id)

      local path_from = nil
      local path_to = nil

      if (bline) then
        path_from = bline.path
      end

      -- iterate backwards from this line in the tree, until we hit a line with a parsable bid?
      local line_indent = line:match("^%s*") or ""
      local line_index = index;
      local path_id_above_less_indent = nil
      while line_index > 1 and (not path_id_above_less_indent) do
        line_index = line_index - 1

        local line_above = current_lines[line_index]
        local line_indent_above = line_above:match("^%s*") or ""
        local path_id_above = utils.get_bid_by_match(line_above)

        if (#line_indent_above < #line_indent and path_id_above) then
          path_id_above_less_indent = path_id_above
        end
      end
      -- if there is nothing above, use the root line
      if (not path_id_above_less_indent) then
        path_id_above_less_indent = tree.lines[1].id
      end
      local parent_bline_by_indent = tree:find_by_id(path_id_above_less_indent)

      -- remove leading whitespace before first char, remove path_id from the end, remove relative path
      local edited_line = line:gsub("^%s*", ""):gsub("%[%d+%]$", "")
      local edited_line_name = vim.fn.fnamemodify(edited_line, ':t')

      -- special case for the root node
      if (bline and bline.path == tree.lines[1].path) then
        local path_head_dir = vim.fn.fnamemodify(parent_bline_by_indent.path, ':h') or ''
        path_to = path_head_dir .. '/' .. edited_line_name
      else
        -- build the path_to by appending the bline name to the bline above this line
        local path_head = vim.fn.fnamemodify(parent_bline_by_indent.path, ':p:h') or ''

        if (edited_line_name ~= "") then
          path_to = path_head .. '/' .. edited_line_name
        end
      end


      if (path_from ~= path_to) then
        local id = ('New:' .. index)
        if (path_id) then
          id = tostring(path_id)
        end
        self.current_edits[tostring(id)] = {
          path_from = path_from,
          path_to = path_to,
        }
      end
    end
  end

  -- build deleted lines
  for _, bline in ipairs(tree.lines) do
    -- check if a line with the bid exists after editing
    local current_line_exists = false
    for _, line in ipairs(current_lines) do
      local path_id = utils.get_bid_by_match(line)
      if (path_id == bline.id) then
        current_line_exists = true
        break
      end
    end

    -- if not, we deleted it
    if (not current_line_exists) then
      if (bline.file_type == 'directory') then
        tree:remove_children(bline.children)
      end

      self.current_edits[tostring(bline.id)] = {
        path_from = bline.path,
        path_to = nil,
      }
    end
  end
  print("edits", vim.inspect(self.current_edits))
end

return Editor
