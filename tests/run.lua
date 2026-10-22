-- nvim --headless -u NONE -l tests/run.lua (or `mise run test`)
-- The hover needs a live debug adapter, so it isn't covered here.
vim.opt.rtp:prepend(".")

local render = require("dap-batteries.render")
local function eq(got, want, what)
  assert(got == want, ("%s: got %s, want %s"):format(what, vim.inspect(got), vim.inspect(want)))
end

-- Types and values.
eq(render.short_type("github.com/org/repo/pkg/catalog.Catalog"), "catalog.Catalog", "plain type")
eq(render.short_type("[]github.com/org/repo/pkg/catalog.Entry"), "[]catalog.Entry", "slice")
eq(render.short_type("map[string]*github.com/a/b-c/v0.ServerJSON"), "map[string]*v0.ServerJSON", "map of pointers")
eq(render.short_type("map[string]interface {}"), "map[string]interface {}", "no path")
eq(render.hide_int_hex("507557000 = 0x1e40b488"), "507557000", "int with hex")
eq(render.hide_int_hex("-1 = 0xffffffffffffffff"), "-1", "negative int")
eq(render.hide_int_hex('"https://x.io/a = 0x1"'), '"https://x.io/a = 0x1"', "string stays")

-- Window behaviours: stub the quit, keep everything else real.
local quits = 0
local real_cmd = vim.cmd
vim.cmd = setmetatable({
  qall = function()
    quits = quits + 1
  end,
}, {
  __index = real_cmd,
  __call = function(_, ...)
    return real_cmd(...)
  end,
})
require("dap-batteries").setup({ hover = { enabled = false } })

local function scratch(ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = ft
  return buf
end
local function split_with(ft)
  local win = vim.api.nvim_open_win(scratch(ft), false, { split = "right", win = 0 })
  vim.wait(20)
  return win
end
local function reset()
  real_cmd("silent! only!")
  vim.cmd.enew({ bang = true })
  quits = 0
end

-- The last editor window closes next to a sidebar and a panel: quit.
reset()
local editor = vim.api.nvim_get_current_win()
split_with("neo-tree")
split_with("dapui_scopes")
vim.api.nvim_win_close(editor, true)
vim.wait(50)
eq(quits, 1, "quit after the last editor window")

-- Another editor window is left: stay.
reset()
editor = vim.api.nvim_get_current_win()
vim.api.nvim_open_win(vim.api.nvim_create_buf(true, false), false, { split = "right", win = 0 })
split_with("dapui_scopes")
vim.api.nvim_win_close(editor, true)
vim.wait(50)
eq(quits, 0, "stay while an editor window is left")

-- Closing a panel never quits, even with no editor window around.
reset()
split_with("neo-tree")
local panel = split_with("dapui_stacks")
vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true)
vim.wait(50) -- that was the last editor window, so let its quit run first
quits = 0
vim.api.nvim_win_close(panel, true)
vim.wait(50)
eq(quits, 0, "closing a panel doesn't quit")

-- A file opened in a panel window goes to the editor window instead.
reset()
editor = vim.api.nvim_get_current_win()
panel = split_with("dapui_watches")
local panel_buf = vim.api.nvim_win_get_buf(panel)
local file = vim.fn.tempname() .. ".txt"
vim.fn.writefile({ "hello" }, file)
vim.api.nvim_set_current_win(panel)
real_cmd.edit(file)
vim.wait(50)
eq(vim.api.nvim_win_get_buf(panel), panel_buf, "panel keeps its buffer")
eq(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(editor)), vim.uv.fs_realpath(file), "file lands in the editor")
eq(vim.api.nvim_get_current_win(), editor, "focus follows the file")
vim.fn.delete(file)

print("ok")
