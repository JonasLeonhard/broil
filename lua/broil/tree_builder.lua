local BLine = require('broil.bline')
local config = require('broil.config')
local fzf = require('fzf_lib')
local utils = require('broil.utils')

local Tree_Builder = {}
Tree_Builder.__index = Tree_Builder

--- @param path string
--- @param options broil.TreeBuilderOptions
function Tree_Builder:new(path, options)
  local tree_builder = {}
  setmetatable(tree_builder, Tree_Builder)

  local dir_of_path = path
  if (vim.loop.fs_stat(path).type ~= 'directory') then
    dir_of_path = vim.fn.fnamemodify(path, ':h')
  end

  tree_builder.path = dir_of_path                    -- the dir of the opened path
  tree_builder.open_path = path                      -- the original open path
  tree_builder.optimal_lines = options.optimal_lines -- can be nil for infinite search
  tree_builder.pattern = options.pattern

  tree_builder.fzf_slab = fzf.allocate_slab()
  tree_builder.fzf_pattern_obj = fzf.parse_pattern(options.pattern, config.fzf_case_mode, config.fzf_fuzzy_match)

  tree_builder.blines = {}

  local bline = BLine:new({
    parent_id = nil,
    path = tree_builder.path,
    relative_path = '',
    depth = 0,
    name = vim.fn.fnamemodify(path, ':t') or '', -- tail of tree path,
    children = {},
    file_type = 'directory',
    has_match = true, -- always show the root node
    score = 0,
    fzf_score = 0,
    fzf_pos = {},
    nb_kept_children = 0, -- todo? amount of kept children
    next_child_idx = 1,   -- this is used for building the tree only. It keeps track of the node from wich to continue building the tree after touching the current dir.
    left_branches = {},   -- table<depth, boolean>: depths where the branch has a left branch
    unlisted = 0,         -- amount of unlisted children. This will be set later
  })
  tree_builder.root_id = bline.id
  table.insert(tree_builder.blines, bline.id, bline)

  return tree_builder
end

--- gathers a list of matching bline ids via breadth-first search (BFS) from the root node of the tree, also loads the children traversed dir nodes
function Tree_Builder:gather_lines()
  local search_size = self.optimal_lines
  if (self.optimal_lines and self.pattern ~= '') then
    -- we increase the search_size temporarily, those lines will be pruned back to the optimal_lines size with only the best scores
    search_size = self.optimal_lines * 10
  end

  -- go through all open_dirs and process their blines one by one until you found matching lines equal to the optimal_size
  --- @type broil.BId[]
  local out_lines = { self.root_id }
  local open_dirs = { self.root_id }
  local next_level_dirs = {}
  local matching_lines = 1
  while true do
    if (self.optimal_lines and matching_lines >= search_size) then
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
          matching_lines = matching_lines + 1
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
        -- TODO: refactor this into a function? set_has_match_of_all_ancestors_if_matching
        table.insert(open_dirs, next_level_dir_id)
        local has_child_match = self:load_children(next_level_dir_id);

        -- set has_match of all ancestors aswell
        if (has_child_match) then
          local id = next_level_dir_id
          while true do
            local bline = self.blines[id];
            if (not bline.has_match) then
              bline.has_match = true
              matching_lines = matching_lines + 1
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

  -- trim_excess: if we increased the search_size temporarily, we prune the lines back to the optimal_lines size keeping only the lines with the best scores
  if (self.optimal_lines) then
    local count = 1

    -- increment the parents kept_children counter for each matched line
    for i = 2, #out_lines do
      local bline = self.blines[out_lines[i]]
      if (bline.parent_id and bline.has_match) then
        count = count + 1
        self.blines[bline.parent_id].nb_kept_children = self.blines[bline.parent_id].nb_kept_children + 1;
      end
    end
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

      self.blines[bline_child.id] = bline_child
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
  local relative_path = string.gsub(path, utils.escape_pattern(self.path .. '/'), '')
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
    nb_kept_children = 0,
    left_branches = {},
    unlisted = 0
  })
end

--- @param bline_ids broil.BId[]
function Tree_Builder:as_tree(bline_ids)
  -- build tree_lines with only matching nodes from ids
  local tree_lines = {}
  local bid_lines = {}
  local bid_parents = {}
  for _, bline_id in ipairs(bline_ids) do
    local bline = self.blines[bline_id]

    -- set amount of unlisted children
    bline.unlisted = #bline.children - (bline.next_child_idx - 1)

    -- always insert all nodes when searching for nothing, otherwise only if it matches
    if (self.pattern == '' or bline.has_match) then
      table.insert(tree_lines, bline)
    end

    if (bline.parent_id) then
      bid_parents[bline.id] = bline.parent_id
    end
    bid_lines[bline.id] = bline
  end

  -- we need to order the lines to build the tree.
  -- It's a little complicated because
  --  - we want a case insensitive sort
  --  - we still don't want to confuse the children of AA and Aa
  --  - a node can come from a not parent node, when we followed a link
  local sort_paths = {}
  for i = 1, #tree_lines do
    local sort_path = ''
    local bid = tree_lines[i].id;

    while true do
      local sort_prefix = ''
      local bline = bid_lines[bid]

      if (config.sort_option == 'TypeDirsFirst') then
        if (bline.file_type == 'directory') then
          sort_prefix = '              '
        else
          sort_prefix = vim.fn.expand(bline.path .. ':e') -- path_extension
        end
      else
        if (bline.file_type == 'directory') then
          sort_prefix = '~~~~~~~~~~~~~~'
        else
          sort_prefix = vim.fn.expand(bline.path .. ':e') -- path_extension
        end
      end
      sort_path = string.format("%s%s-%s/%s", sort_prefix, bline.name:lower(), bline.id, sort_path)
      if (bid_parents[bid]) then
        bid = bid_parents[bid]
      else
        break
      end
    end
    sort_paths[tree_lines[i].id] = sort_path
  end

  -- sorting paths into tree-clusters
  table.sort(tree_lines, function(a, b)
    return sort_paths[a.id] < sort_paths[b.id]
  end)

  -- get the best scoring node & the opened index to select later
  local highest_score_index = 1
  local open_path_index = 1

  for i, bline in ipairs(tree_lines) do
    if (bline.score > tree_lines[highest_score_index].score) then
      highest_score_index = i
    end

    if (bline.path == self.open_path) then
      open_path_index = i
    end
  end

  -- iterate the tree_lines from bottom to top, skip the root node at index 1
  -- get the parent line and create a range from the parent to the current_line. start => parent_index + 1, and end => current_index
  -- set the left_branches of all lines in the range to the depth
  local last_parent_index = #tree_lines
  for end_index = #tree_lines, 1, -1 do
    -- find the parent_index of the line by iterating from the line index upwards until you get the parent
    local parent_index
    if (tree_lines[end_index].parent_id) then
      local index = end_index
      while index > 1 do
        index = index - 1
        if (tree_lines[index].id == tree_lines[end_index].parent_id) then
          break
        end
      end
      parent_index = index
    else
      parent_index = end_index
    end

    -- take the last child of a parent with unlisted children, and turn it to a pruning line instead. Unsetting the unlisted of the parent
    if (parent_index ~= last_parent_index) then
      local unlisted = tree_lines[parent_index].unlisted
      if (unlisted > 0 and tree_lines[end_index].nb_kept_children == 0 and highest_score_index ~= end_index) then
        tree_lines[end_index].line_type = 'pruning'
        tree_lines[end_index].unlisted = unlisted + 1
        tree_lines[end_index].name = tostring(unlisted + 1) .. " unlisted"
        tree_lines[parent_index].unlisted = 0
      end
      last_parent_index = parent_index
    end

    -- set all branches in from this line to the parent as a left branch
    local parent_depth = tree_lines[parent_index].depth
    for i = parent_index + 1, end_index do
      tree_lines[i].left_branches[tostring(parent_depth)] = true
    end
  end

  return {
    lines = tree_lines,
    highest_score_index = highest_score_index,
    open_path_index = open_path_index,
  }
end

function Tree_Builder:build_tree()
  local root_node = self.blines[self.root_id]

  if (not root_node) then
    return {}
  end

  self:load_children(root_node.id)      -- load the root nodes children
  local bline_ids = self:gather_lines() -- unsorted bids
  return self:as_tree(bline_ids)        -- structure with sorted and clustered blines
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
