local config = {
  mappings = {
    -- general
    help = '?',
    synchronize = '<C-y>',
    close = '<C-q>',
    pop_history = '<C-p>',

    -- search
    select_next_node = '<C-j>',
    select_next_node_normal = 'j',
    select_prev_node = '<C-k>',
    select_prev_node_normal = 'k',
    open_selected_node = '<CR>',
    open_selected_node2 = '<C-l>',
    open_parent_dir = '<C-h>',
    open_edits_float = '<C-e>'
  },
  special_paths = {
    ["media"] = "no-enter",
    [".git"] = "no-enter",
    ["node_modules"] = "no-enter",
    ["vendor"] = "no-enter",
    [".svelte-kit"] = "no-enter",
    ["dist"] = "no-enter",
    ["target"] = "no-enter",
    ["debug"] = "no-enter",
    ["release"] = "no-enter",
    ["build"] = "no-enter",
    ["tmp"] = "no-enter",
    [".next"] = "no-enter",
    [".DS_Store"] = "hide",
  },

  -- runtime configs
  fzf_case_mode = 0,             -- case_mode: number with 0 = smart_case, 1 = ignore_case, 2 = respect_case
  fzf_fuzzy_match = true,
  show_hidden = true,            -- files/dirs with '.'
  sort_option = 'TypeDirsFirst', -- or 'TypeDirsLast'
  file_size_preview_limit_mb = 5,
}

--- @param opts table|nil configuration See |broil.config|.
config.set = function(opts)
  local new_conf = vim.tbl_deep_extend("keep", opts or {}, config)
  for k, v in pairs(new_conf) do
    config[k] = v
  end
end

return config
