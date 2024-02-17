local utils = {}

--- use like this: local current_matched = fuzzy_match(node.relative_path, search_term)
--- @return table|nil
utils.fuzzy_match = function(str, pattern)
  local pattern_idx = 1
  local match_indices = {}
  for i = 1, #str do
    if str:sub(i, i):lower() == pattern:sub(pattern_idx, pattern_idx):lower() then
      table.insert(match_indices, i)
      pattern_idx = pattern_idx + 1
      if pattern_idx > #pattern then
        return match_indices
      end
    end
  end
  return nil
end


return utils
