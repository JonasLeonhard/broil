--- @class broil.TreeBuilderOptions
--- @field pattern string -- search pattern to filter /order the tree by
--- @field optimal_lines integer|nil how many lines to build a tree for. Nil equals a total search

--- @alias broil.BId integer

--- @alias broil.FileType 'directory'|'file'
---
--- @class broil.BLine
--- @field id broil.BId|nil
--- @field parent_id broil.BId|nil parent id
--- @field path string path of the bline
--- @field relative_path string relative to the tree
--- @field depth integer depth of the bline
--- @field name string
--- @field has_match boolean wheter search pattern matched something
--- @field file_type broil.FileType
--- @field children broil.BId[] sorted and filtered
--- @field next_child_idx integer index for iteration, among the children
--- @field score integer composite ordering score, takes in count fzf match, depth ordering...
--- @field fzf_score integer reals fzf match score of how good the search pattern matches the line
--- @field fzf_pos table positions that matched the search term chars, eg: {1, 3, 4}
--- @field nb_kept_children integer used during the trimming step
--- @field read_dir function|nil -> @return broil.ReadDir[]

--- @class broil.TreeOptions
--- @field lines broil.BLine[]
--- @field selected_index integer
--- @field buf_id integer
--- @field win_id integer
