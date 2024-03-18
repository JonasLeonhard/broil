--- @class broil.TreeBuilderOptions
--- @field pattern string -- search pattern to filter /order the tree by
--- @field optimal_lines integer|nil how many lines to build a tree for. Nil equals a total search
--- @field maximum_search_time_sec integer time in seconds when to stop the search

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
--- @field line_type string|nil
--- @field children broil.BId[] sorted and filtered
--- @field next_child_idx integer index for iteration, among the children
--- @field score integer composite ordering score, takes in count fzf match, depth ordering...
--- @field fzf_score integer reals fzf match score of how good the search pattern matches the line
--- @field fzf_pos table positions that matched the search term chars, eg: {1, 3, 4}
--- @field nb_kept_children integer used during the trimming step
--- @field read_dir function|nil -> @return broil.ReadDir[]
--- @field rendered string|nil -> how the bline was rendered originally, can be used to detect if changes are made
--- @field extmark table|nil -> set_extmarks opts
--- @field file_extension string|nil -> set only after rendering icons
--- @field fs_stat table|nil

--- @class broil.TreeOptions
--- @field pattern string
--- @field lines broil.BLine[]
--- @field highest_score_index integer
--- @field open_path_index integer -- if broil was opened with a path for a file / dir, this is the index of the line
--- @field buf_id integer
--- @field win_id integer

--- @class broil.Edit
--- @field bid broil.BId|nil -- bline id the edit was made on
--- @field path_from string -- path of what was edited
--- @field path_to string|nil -- path of where it is edited to

--- @class broil.Editor
--- @field edits broil.Edit[]
--- @field handle_edits function
--- @field current_edits broil.Edit[]
--- @field building boolean wheter we are currently building edits
