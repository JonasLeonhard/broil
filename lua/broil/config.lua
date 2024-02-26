local config = {
  mappings = {
    -- general
    help = '?',

    -- tree buffer
    synchronize = '<C-y>', -- toggle tree and buffer view

    -- search
    close_float = '<C-q>',
    select_next_node = '<C-j>',
    select_prev_node = '<C-k>',
    open_selected_node = '<CR>',
    open_selected_node2 = '<C-l>',
    open_parent_dir = '<C-h>'
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
  fzf_case_mode = 0, -- case_mode: number with 0 = smart_case, 1 = ignore_case, 2 = respect_case
  fzf_fuzzy_match = true,
  show_hidden = false,
  sort_option = 'TypeDirsFirst' -- or 'TypeDirsLast'
}

--- @param opts table|nil configuration See |broil.config|.
config.set = function(opts)
  local new_conf = vim.tbl_deep_extend("keep", opts or {}, config)
  for k, v in pairs(new_conf) do
    config[k] = v
  end
end

return config
