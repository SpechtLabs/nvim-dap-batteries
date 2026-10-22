-- Window housekeeping around the dap-ui panels.

local M = {}

-- Filetypes of the dap-ui panels and the repl.
M.filetypes = {
  "dapui_scopes",
  "dapui_breakpoints",
  "dapui_stacks",
  "dapui_watches",
  "dapui_console",
  "dapui_hover",
  "dap-repl",
}

-- dap-ui's `force_buffers` cannot keep files out of its panels: it swaps the
-- panel buffer back from inside BufWinEnter, but `:edit` (and everything built
-- on it: LSP jumps, quickfix, pickers) then either finishes and puts the file
-- into the window anyway, or, for an already loaded buffer, loses the file
-- entirely. So with `force_buffers` off this does the job: when a non-panel
-- buffer shows up in a window that held a dap panel, hand the buffer to the
-- last editor window and restore the panel. `winfixbuf` was rejected because
-- it makes those openers fail with E1513 instead of picking a window.
---@param enabled boolean
function M.keep_files_out(enabled)
  local group = vim.api.nvim_create_augroup("DapBatteriesKeepFilesOut", {})
  if not enabled then
    return
  end

  local function is_editor_win(win)
    local buf = vim.api.nvim_win_get_buf(win)
    return vim.api.nvim_win_get_config(win).relative == ""
      and vim.bo[buf].buftype == ""
      and not vim.w[win].dap_panel_buf
  end

  vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if is_editor_win(win) then
        vim.t.last_editor_win = win
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(ev)
      local win = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        return
      end

      if vim.tbl_contains(M.filetypes, vim.bo[ev.buf].filetype) then
        vim.w[win].dap_panel_buf = ev.buf
        return
      end

      local panel_buf = vim.w[win].dap_panel_buf
      if not panel_buf or not vim.api.nvim_buf_is_valid(panel_buf) then
        return
      end

      -- Defer: the opener is still mid-flight and would overwrite a swap done now.
      vim.schedule(function()
        if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= ev.buf then
          return
        end

        local cursor = vim.api.nvim_win_get_cursor(win)
        local was_current = vim.api.nvim_get_current_win() == win
        local target = vim.t.last_editor_win
        if not (target and vim.api.nvim_win_is_valid(target) and is_editor_win(target)) then
          target = vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(is_editor_win)
        end
        if not target then
          -- No editor window left: open one beside the panels.
          target = vim.api.nvim_open_win(ev.buf, false, { split = "above", win = win })
        end

        vim.api.nvim_win_set_buf(win, panel_buf)
        vim.api.nvim_win_set_buf(target, ev.buf)
        pcall(vim.api.nvim_win_set_cursor, target, cursor)
        if was_current then
          vim.api.nvim_set_current_win(target)
        end
      end)
    end,
  })
end

-- A file tree's own "close if last window" (neo-tree's `close_if_last_window`)
-- never fires while the dap panels are open, since they count as windows too.
-- So when the last editor window closes and only dap panels and sidebars are
-- left, quit, or close the tab if there are others. nvim-dap terminates the
-- session on ExitPre, and unsaved hidden buffers still stop the quit with E37.
-- Closing a panel never quits, only closing an editor window does.
---@param opts { enabled: boolean, sidebars: string[] }
function M.quit_with_last_editor(opts)
  local group = vim.api.nvim_create_augroup("DapBatteriesQuitWithLastEditor", {})
  if not opts.enabled then
    return
  end

  local function is_panel(win)
    local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
    return vim.tbl_contains(opts.sidebars, ft) or vim.tbl_contains(M.filetypes, ft)
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      local closed = tonumber(ev.match)
      if vim.api.nvim_win_get_config(closed).relative ~= "" or is_panel(closed) then
        return
      end
      vim.schedule(function()
        local wins = vim.tbl_filter(function(win)
          return vim.api.nvim_win_get_config(win).relative == ""
        end, vim.api.nvim_tabpage_list_wins(0))
        if not vim.iter(wins):all(is_panel) then
          return
        end
        if #vim.api.nvim_list_tabpages() > 1 then
          vim.cmd.tabclose()
        else
          -- E37 for unsaved hidden buffers: a warning, not a callback traceback.
          local ok, err = pcall(vim.cmd.qall)
          if not ok then
            vim.notify(err, vim.log.levels.WARN)
          end
        end
      end)
    end,
  })
end

return M
