-- lazy.nvim specs with the preferred defaults for the plugins this wraps.
-- Import them with `{ "SpechtLabs/nvim-dap-batteries", import = "dap-batteries.plugins" }`
-- and override anything with your own spec for the same plugin, after the
-- import: lazy.nvim merges `opts`, and a key with the same lhs replaces this one
-- (`{ "<leader>du", false }` drops it).

return {
  {
    "SpechtLabs/nvim-dap-batteries",
    main = "dap-batteries",
    -- Only autocmds at startup; dap itself still loads on first use.
    lazy = false,
    opts = {},
  },

  {
    "mfussenegger/nvim-dap",
    keys = {
      {
        "<F5>",
        function()
          require("dap").continue()
        end,
        desc = "Continue (F5)",
      },
      {
        "<leader>dd",
        function()
          require("dap").continue()
        end,
        desc = "Continue (F5)",
      },
      {
        "<leader>dq",
        function()
          require("dap").terminate()
        end,
        desc = "Quit/Terminate",
      },
      {
        "<F9>",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint (F9)",
      },
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint (F9)",
      },
      {
        "<F10>",
        function()
          require("dap").step_over()
        end,
        desc = "Step Over (F10)",
      },
      {
        "<leader>do",
        function()
          require("dap").step_over()
        end,
        desc = "Step Over (F10)",
      },
      {
        "<F11>",
        function()
          require("dap").step_into()
        end,
        desc = "Step Into (F11)",
      },
      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "Step Into (F11)",
      },
      {
        "<leader>dr",
        function()
          require("dapui").toggle()
        end,
        desc = "Toggle Debug UI",
      },
      {
        "<leader>dB",
        function()
          local widgets = require("dap.ui.widgets")
          widgets.sidebar(widgets.breakpoints).open()
        end,
        desc = "View Breakpoints",
      },
    },
  },

  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    -- On this spec, not nvim-dap's, because LazyVim binds <leader>du and
    -- <leader>de on nvim-dap-ui: same plugin, same lhs is what replaces a key.
    keys = {
      {
        "<leader>du",
        function()
          require("dap").step_out()
        end,
        desc = "Step Out",
      },
      {
        "<leader>de",
        function()
          require("dapui").eval()
        end,
        desc = "Eval Expression",
        mode = { "n", "v" },
      },
    },
    opts = {
      -- Replaced by the plugin's `keep_files_out_of_panels`. Set it back to true
      -- if you turn that off.
      force_buffers = false,

      -- Without a cap the hover/eval float grows to the longest line, which for
      -- a map or slice is wider than the screen: it then spans the whole editor
      -- and is shifted one column off the left edge. Fractions are of the
      -- screen; longer lines are cut, expand the value with <CR> instead.
      floating = {
        max_width = 0.5,
        max_height = 0.4,
        border = "rounded",
      },

      -- The breakpoints and stacks elements only have `open` (jump to the
      -- location), not `expand`, which the global mappings bind to <CR> and
      -- double-click. Bind those to `open` for these elements. Scopes and
      -- watches keep <CR> for expanding variables.
      element_mappings = {
        breakpoints = {
          open = { "o", "<CR>", "<2-LeftMouse>" },
          expand = {},
        },
        stacks = {
          open = { "o", "<CR>", "<2-LeftMouse>" },
          expand = {},
        },
      },

      -- Bottom bar (repl, console, watches) across the full width, panel column
      -- (scopes, breakpoints, stacks) on the right above it. Sizes below 1 are
      -- fractions: of the screen for a layout, of the layout for its elements.
      -- `layouts` is a list, so it replaces the default list instead of merging.
      -- Each layout opens with `botright`, so the one opened last is outermost:
      -- the order here is deliberate. Swap it and the right column would run the
      -- full height and the bottom bar would stop at its edge.
      layouts = {
        {
          elements = {
            { id = "repl", size = 0.3 },
            { id = "console", size = 0.3 },
            { id = "watches", size = 0.3 },
          },
          size = 0.25,
          position = "bottom",
        },
        {
          elements = {
            { id = "scopes", size = 0.3 },
            { id = "breakpoints", size = 0.3 },
            { id = "stacks", size = 0.3 },
          },
          size = 0.3,
          position = "right",
        },
      },
    },
    -- Same as LazyVim's (which this replaces), so it also works without
    -- LazyVim, plus the render tweaks once dap-ui is loaded.
    config = function(_, opts)
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup(opts)
      require("dap-batteries.render").apply()
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open({})
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close({})
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close({})
      end
    end,
  },

  {
    "leoluz/nvim-dap-go",
    -- Only if you use nvim-dap-go already (LazyVim's lang.go extra does).
    optional = true,
    opts = {
      delve = {
        -- Works around delve failing on DWARF 5 debug info: build without
        -- optimisations or inlining, and with uncompressed debug info.
        build_flags = "-gcflags='all=-N -l' -ldflags='-compressdwarf=false'",
      },
    },
  },

  {
    -- Skip the panels when neo-tree picks a window to open a file in. neo-tree
    -- replaces this list rather than merging it, so start from its defaults.
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = function(_, opts)
      opts.open_files_do_not_replace_types = vim.list_extend(
        opts.open_files_do_not_replace_types or { "terminal", "Trouble", "qf", "edgy" },
        require("dap-batteries.panels").filetypes
      )
    end,
  },
}
