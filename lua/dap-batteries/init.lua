-- nvim-dap-batteries: opinionated defaults and a few extra behaviours on top of
-- nvim-dap and nvim-dap-ui. The debugging itself is all theirs; this module
-- only holds the options for the extras and switches them on. The defaults for
-- the wrapped plugins (keys, dap-ui layout) live in `dap-batteries.plugins`.

local M = {}

---@class dap-batteries.Config
M.defaults = {
  -- While the debugger is paused, show the value under the cursor in a dap-ui
  -- float once the cursor has sat still for `delay` ms, expanded `depth`
  -- levels deep until it holds `max_lines` lines.
  hover = { enabled = true, delay = 500, depth = 3, max_lines = 40 },
  -- Drop the import path from types in all dap-ui elements:
  -- `github.com/org/repo/pkg/catalog.Entry` becomes `catalog.Entry`.
  short_types = true,
  -- Show `42` instead of delve's `42 = 0x2a`.
  hide_int_hex = true,
  -- Hand files that get opened into a dap-ui panel window to an editor window
  -- instead. Needs dap-ui's `force_buffers = false` (the default in
  -- `dap-batteries.plugins`), which this replaces.
  keep_files_out_of_panels = true,
  -- When the last editor window closes and only dap-ui panels and the
  -- `sidebars` filetypes are left, quit (or close the tab, if there are more).
  quit_with_last_editor = { enabled = true, sidebars = { "neo-tree", "NvimTree" } },
}

---@type dap-batteries.Config
M.config = vim.deepcopy(M.defaults)

---@param opts? dap-batteries.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  local panels = require("dap-batteries.panels")
  panels.keep_files_out(M.config.keep_files_out_of_panels)
  panels.quit_with_last_editor(M.config.quit_with_last_editor)
  require("dap-batteries.hover").setup(M.config.hover)
  -- Otherwise the dap-ui spec in `dap-batteries.plugins` applies it on load.
  if package.loaded["dapui"] then
    require("dap-batteries.render").apply()
  end
end

return M
