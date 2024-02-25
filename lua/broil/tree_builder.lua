local BLine = require('broil.bline')
local config = require('broil.config')
local fzf = require('fzf_lib')

local Tree_Builder = {}
Tree_Builder.__index = Tree_Builder

--- @param path string
--- @param options broil.TreeOptions
function Tree_Builder:new(path, options)
  local tree_builder = {}
  setmetatable(tree_builder, Tree_Builder)

  tree_builder.path = path
  tree_builder.optimal_lines = options.optimal_lines
  tree_builder.pattern = options.pattern

  tree_builder.fzf_slab = fzf.allocate_slab()
  tree_builder.fzf_pattern_obj = fzf.parse_pattern(options.pattern, config.fzf_case_mode, config.fzf_fuzzy_match)

  tree_builder.blines = {}

  local bline = BLine:new({
    parent_id = nil,
    path = path,
    relative_path = '',
    depth = 0,
    name = vim.fn.fnamemodify(path, ':t') or '', -- tail of tree path,
    children = {},
    file_type = 'directory',
    has_match = false,
    score = 0,
    fzf_score = 0,
    fzf_pos = {},
    nb_kept_children = 0,
    next_child_idx = 1, -- this is used for building the tree only. It keeps track of the node from wich to continue building the tree after touching the current dir.
  })
  tree_builder.root_id = bline.id
  table.insert(tree_builder.blines, bline.id, bline)

  return tree_builder
end

--- gathers a list of matching bline ids via breadth-first search (BFS) from the root node of the tree, also loads the children traversed dir nodes
function Tree_Builder:gather_lines()
  --- @type broil.BId[]
  local out_lines = { self.root_id }
  local open_dirs = { self.root_id }
  local next_level_dirs = {}
  local nb_lines_ok = 1
  local optimal_size = self.optimal_lines
  if (self.pattern ~= '') then
    optimal_size = self.optimal_lines * 10
  end

  -- go through all open_dirs and process their blines one by one until you reached the optimal_size
  while true do
    if (nb_lines_ok >= optimal_size) then
      break
    end

    local open_dir_id = table.remove(open_dirs, 1)
    if (open_dir_id) then
      local child_id = self:next_child(open_dir_id)
      if (child_id) then
        -- process just one bline of this dir, then append it to the queue again
        table.insert(open_dirs, open_dir_id)
        local child = self.blines[child_id]

        if (child.has_match) then
          nb_lines_ok = nb_lines_ok + 1
        end

        -- if its a dir, enter its childs in the next iteration aswell
        if (child:can_enter()) then
          table.insert(next_level_dirs, child_id)
        end

        table.insert(out_lines, child_id)
      end
    else
      -- this depth finished, no dirs are open
      if (#next_level_dirs == 0) then
        break -- no more dirs to process
      end

      for _, next_level_dir_id in ipairs(next_level_dirs) do
        -- TODO: if dam.has_event() { to interupt async build task?
        table.insert(open_dirs, next_level_dir_id)
        local has_child_match = self:load_children(next_level_dir_id);

        if (has_child_match) then
          -- we must ensure the ancestors are made Ok
          local id = next_level_dir_id
          while true do
            local bline = self.blines[id];
            if (not bline.has_match) then
              bline.has_match = true
              nb_lines_ok = nb_lines_ok + 1
            end

            if (bline.parent_id) then
              id = bline.parent_id
            else
              break
            end
          end
        end
        table.insert(open_dirs, next_level_dir_id)
      end

      next_level_dirs = {}
    end
  end

  -- if the root directory isn't totally read, we finish it even if it would go over the optimal_size
  local root_next_child_id = self:next_child(self.root_id)
  while root_next_child_id do
    table.insert(out_lines, root_next_child_id)
    root_next_child_id = self:next_child(self.root_id)
  end

  return out_lines
end

--- return the next child of a blines children if called multiple times.
--- This increments the next_child_idx of the parent_id bline
--- @param parent_id broil.BId
function Tree_Builder:next_child(parent_id)
  local bline = self.blines[parent_id]

  if (not bline) then
    return nil
  end

  if (bline.next_child_idx > #bline.children) then
    return nil
  end

  local next_child = bline.children[bline.next_child_idx];
  bline.next_child_idx = bline.next_child_idx + 1
  return next_child
end

--- loads the direct children of a bId in tree_builder.blines for any given bId
--- @param bId broil.BId
--- @return boolean has_child_match a boolean when there are direct matches among children
function Tree_Builder:load_children(bId)
  local has_child_match = false
  local children = {}

  --- @type broil.BLine
  local bline = self.blines[bId]

  if (not bline) then
    return false
  end

  bline:read_dir(function(name, type)
    local bline_child = self:create_bline(bline, name, type)

    if (bline_child) then
      -- if the bline matches, the parent matches aswell
      if (bline_child.has_match) then
        self.blines[bId].has_match = true;
        has_child_match = true
      end

      table.insert(self.blines, bline_child.id, bline_child)
      table.insert(children, bline_child.id)
    end
  end)

  -- TODO: sort children by name? is this already sorted?
  self.blines[bId].children = children

  return has_child_match
end

--- @param parent_bline broil.BLine
--- @param name string
--- @param type broil.FileType
--- @return broil.BLine|nil
function Tree_Builder:create_bline(parent_bline, name, type)
  if (not name or not type) then
    return nil
  end

  if (config.special_paths[name] == 'hide') then
    return nil
  end

  if (name:sub(1, 1) == '.' and not config.show_hidden) then
    return nil
  end

  local path = parent_bline.path .. '/' .. name
  local relative_path = string.gsub(path, self.path .. '/', '')

  local score = 10000 - parent_bline.depth + 1 -- // we rank less deep entries higher
  local fzf_score = fzf.get_score(relative_path, self.fzf_pattern_obj, self.fzf_slab)
  local fzf_pos = fzf.get_pos(relative_path, self.fzf_pattern_obj, self.fzf_slab)
  local has_match = fzf_score > 0

  if (fzf_score > 0) then
    score = score + fzf_score + 10 -- // we dope direct matches to compensate for depth doping of parent folders
  end

  if (type == 'file' and not has_match) then
    return nil
  end

  return BLine:new({
    parent_id = parent_bline.id,
    path = path,
    relative_path = relative_path,
    depth = parent_bline.depth + 1,
    name = name,
    has_match = has_match,
    children = {},
    next_child_idx = 1,
    file_type = type,
    score = score,
    fzf_score = fzf_score or 0,
    fzf_pos = fzf_pos or {},
    nb_kept_children = 0
  })
end

--- @param bline_ids broil.BId[]
function Tree_Builder:as_tree(bline_ids)
  local tree_lines = {}
  for _, bline_id in ipairs(bline_ids) do
    local bline = self.blines[bline_id]
    -- we need to count the children, so we load them
    if (bline.type == 'directory' and #bline.children == 0) then
      self:load_children(bline.id)
    end

    -- always insert all nodes when searching for nothing, otherwise only if it matches
    if (self.pattern == '' or bline.has_match) then
      table.insert(tree_lines, bline)
    end
  end
  return tree_lines
end

function Tree_Builder:build_tree()
  local root_node = self.blines[self.root_id]

  if (not root_node) then
    return {}
  end
  self:load_children(root_node.id) -- load the root nodes children
  local bline_ids = self:gather_lines()
  return self:as_tree(bline_ids)
end

function Tree_Builder:destroy()
  if (self.fzf_slab) then
    fzf.free_slab(self.fzf_slab)
  end

  if (self.fzf_pattern_obj) then
    fzf.free_pattern(self.fzf_pattern_obj)
  end
end

return Tree_Builder
