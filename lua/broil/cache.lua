local Cache = {
  bline_id_cache = {}, -- table: path -> bline_id
  render_cache = {}    -- [buf_id] -> {bid: bline}
}

return Cache;
