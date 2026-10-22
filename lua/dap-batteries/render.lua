-- Shorter types and values in every dap-ui element (hover, scopes, watches):
-- they all render through `dapui.util.render_type` and `format_value`, so
-- wrap those two. If dap-ui renames them, the long forms come back; nothing
-- breaks.

local M = {}

---Strip import paths: everything up to the last `/` of each path, also inside
---composite types like `[]*pkg.T` or `map[string]pkg.T`. Go types only contain
---`/` in import paths.
---@param t string
---@return string
function M.short_type(t)
  return (t:gsub("[%w%.%-_]+/", ""))
end

---`42 = 0x2a` (delve's integer format) becomes `42`. Every other value is
---left alone, since values can contain URLs or file paths.
---@param value string
---@return string
function M.hide_int_hex(value)
  return value:match("^(%-?%d+) = 0x%x+$") or value
end

local applied = false

function M.apply()
  if applied then
    return
  end
  applied = true
  local config = require("dap-batteries").config
  local util = require("dapui.util")
  local render_type, format_value = util.render_type, util.format_value
  util.render_type = function(t)
    return render_type(t and config.short_types and M.short_type(t) or t)
  end
  util.format_value = function(start, value)
    return format_value(start, config.hide_int_hex and M.hide_int_hex(value) or value)
  end
end

return M
