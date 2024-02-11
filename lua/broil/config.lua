local config = {
  mappings = {
    synchronize = '<C-y>',
    help = '?',
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
