# nvim-dap-batteries

My debugging setup for Neovim, packaged so I don't have to copy it between
machines. It is a thin wrapper. All the debugging is done by
[nvim-dap](https://github.com/mfussenegger/nvim-dap) and
[nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui). This plugin ships my
preferred options for them, plus a few behaviours they don't have. Everything
can be changed or switched off.

It is built for [lazy.nvim](https://github.com/folke/lazy.nvim) and plays well
with LazyVim's `dap.core` extra.

## What you get

On top of nvim-dap and nvim-dap-ui:

- **Hover on idle.** While the debugger is paused, leave the cursor on a
  variable for half a second and a float shows its value, expanded three
  levels deep. Keywords, comments and names that aren't in scope don't pop
  anything up. The float closes on the next cursor move.
- **Short types.** `github.com/org/repo/pkg/catalog.Entry` shows as
  `catalog.Entry`, in the hover and in the scopes and watches panels. Integers
  show as `42` instead of delve's `42 = 0x2a`.
- **Files stay out of the panels.** A file opened while a dap-ui panel has
  focus (`gd`, quickfix, a picker, neo-tree) lands in an editor window, and the
  panel keeps its contents.
- **Quit with the last file.** When you close the last editor window and only
  dap-ui panels and a file tree are left, Neovim quits, or closes the tab if
  there are others. Unsaved buffers still stop the quit.

And these defaults for the wrapped plugins, in
[`lua/dap-batteries/plugins.lua`](lua/dap-batteries/plugins.lua):

- dap-ui layout. Repl, console and watches go along the bottom, and scopes,
  breakpoints and stacks in a column on the right.
- dap-ui floats capped at half the screen width with a rounded border. Without
  the cap, a long map value makes the float wider than the screen.
- `<CR>` jumps to the location in the breakpoints and stacks panels.
- Keys: `<F5>`/`<leader>dd` continue, `<F9>`/`<leader>db` toggle breakpoint,
  `<F10>`/`<leader>do` step over, `<F11>`/`<leader>di` step into, `<leader>du`
  step out, `<leader>dq` terminate, `<leader>dr` toggle the UI, `<leader>de`
  eval, `<leader>dB` list breakpoints.
- nvim-dap-go builds with `-gcflags='all=-N -l' -ldflags='-compressdwarf=false'`
  to work around delve failing on DWARF 5 debug info. This only applies if you
  already use nvim-dap-go.

## Install

```lua
-- lua/plugins/dap.lua
return {
  { "SpechtLabs/nvim-dap-batteries", import = "dap-batteries.plugins" },
}
```

The `import` pulls in the specs for nvim-dap, nvim-dap-ui (and nvim-nio) and
this plugin. With LazyVim, keep the `dap.core` extra and load this after it.
The default `{ import = "plugins" }` in LazyVim's starter already does. The
dap-ui spec here replaces LazyVim's `config` with an equivalent that also
applies the short types.

## Configure

The extras take these options. The values shown are the defaults:

```lua
{
  "SpechtLabs/nvim-dap-batteries",
  import = "dap-batteries.plugins",
  opts = {
    hover = { enabled = true, delay = 500, depth = 3, max_lines = 40 },
    short_types = true,
    hide_int_hex = true,
    keep_files_out_of_panels = true,
    quit_with_last_editor = { enabled = true, sidebars = { "neo-tree", "NvimTree" } },
  },
}
```

`max_lines` stops the hover from expanding once the float has that many lines,
so a slice with a thousand elements doesn't turn into a thousand requests.

The wrapped plugins are configured the usual lazy.nvim way. Add your own spec
for the same plugin after the import. lazy.nvim merges `opts` into the defaults
here, and a key with the same lhs replaces mine:

```lua
{
  "rcarriga/nvim-dap-ui",
  opts = { floating = { border = "single" } },
  keys = {
    { "<leader>du", false }, -- drop my step-out key, get LazyVim's "Dap UI" back
  },
}
```

If you turn off `keep_files_out_of_panels`, set dap-ui's `force_buffers` back
to `true`. The default here is `false` because the plugin does that job instead.

### Without the import

If you'd rather write the specs for nvim-dap and nvim-dap-ui yourself, call
`setup` and copy what you want from `plugins.lua`:

```lua
require("dap-batteries").setup({ --[[ options as above ]] })
```

Call it after `require("dapui").setup()`, so the short types reach dap-ui.

## Caveats

The hover expansion and the short types use dap-ui internals: its `expand`
mapping in the hover buffer, and `dapui.util.render_type` and `format_value`.
If dap-ui changes those, the hover stops expanding and the long types come
back. Nothing breaks.

Types are shortened by cutting everything up to the last `/` of each import
path. That is right for Go. For other languages it is a no-op unless their
type names contain slashes.

## Development

```sh
mise run check   # stylua --check and the headless tests
```

## License

[Apache 2.0](LICENSE)
