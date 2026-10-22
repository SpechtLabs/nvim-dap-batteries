-- While the debugger is paused, show the value under the cursor in a dap-ui
-- float once the cursor has sat still for a moment.

local M = {}

-- Open the dap-ui hover float `depth` levels deep, so a struct shows its
-- fields, and slices or nested structs theirs, right away. dap-ui keeps the
-- expand state private (and remembers it across floats), so press its own
-- `expand` mapping on every line of a level that still shows the collapsed
-- icon, wait for the re-render, then do the next level. dap-ui renders
-- asynchronously, hence the waits. Stops once the float holds `max_lines`
-- lines, so a big slice or map doesn't fan out into hundreds of requests.
local function expand(expr, depth, max_lines)
  local buf
  vim.wait(1000, function()
    buf = vim.iter(vim.api.nvim_list_bufs()):find(function(b)
      return vim.bo[b].filetype == "dapui_hover"
    end)
    local first = buf and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    return first:find(expr, 1, true) ~= nil
  end, 20)
  if not buf then
    return
  end

  local config = require("dapui.config")
  for level = 0, depth - 1 do
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- Each render rebinds the mapping, so look it up again every level.
    local map = vim.iter(vim.api.nvim_buf_get_keymap(buf, "n")):find(function(m)
      return m.desc == "expand" and m.callback
    end)
    if #lines > max_lines or not map then
      return
    end

    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local indent = string.rep(" ", level * config.render.indent)
    local expanded = false
    for i, line in ipairs(lines) do
      if vim.startswith(line, indent .. config.icons.collapsed) then
        map.callback(i)
        expanded = true
      end
    end
    if expanded then
      vim.wait(1000, function()
        return vim.api.nvim_buf_get_changedtick(buf) ~= tick
      end, 20)
    end
  end
end

-- A timer rather than CursorHold: that fires after 'updatetime', which also
-- drives swap writes and which LazyVim sets to 200ms. The float closes itself
-- on the next cursor move. The expression is evaluated first and the float
-- only opens if that works, so keywords, comments and out-of-scope names stay
-- quiet instead of popping up an "Unable to evaluate" error.
---@param opts { enabled: boolean, delay: integer, depth: integer, max_lines: integer }
function M.setup(opts)
  local group = vim.api.nvim_create_augroup("DapBatteriesHover", {})
  if not opts.enabled then
    return
  end

  local timer = assert(vim.uv.new_timer())
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      local cursor = vim.api.nvim_win_get_cursor(win)
      local function cursor_still()
        return vim.api.nvim_get_current_win() == win
          and vim.deep_equal(vim.api.nvim_win_get_cursor(win), cursor)
          and vim.api.nvim_get_mode().mode == "n"
      end

      timer:stop()
      timer:start(
        opts.delay,
        0,
        vim.schedule_wrap(function()
          local dap = package.loaded.dap
          local session = dap and dap.session()
          local expr = vim.fn.expand("<cexpr>")
          if not (session and session.current_frame and cursor_still() and vim.bo.buftype == "" and expr ~= "") then
            return
          end
          session:request(
            "evaluate",
            {
              expression = expr,
              frameId = session.current_frame.id,
              context = "hover",
            },
            vim.schedule_wrap(function(err)
              if not err and cursor_still() then
                require("dapui").eval(expr)
                expand(expr, opts.depth, opts.max_lines)
              end
            end)
          )
        end)
      )
    end,
  })
end

return M
