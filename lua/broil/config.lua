local config = {
  mappings = {
    synchronize = '<C-y>',
    help = '?',
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
  }
}

--- @param opts table|nil configuration See |broil.config|.
config.set = function(opts)
  local new_conf = vim.tbl_deep_extend("keep", opts or {}, config)
  for k, v in pairs(new_conf) do
    config[k] = v
  end
end

return config
