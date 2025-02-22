# pydoc.nvim

Fuzzy search Python standard library modules and project modules.

> [!WARNING]
>
> This project is being evaluated/developed. I'll remove this notice once a
> 1.0.0 release has been made. But until then, expect breakage as I'm playing
> around.

## Screenshots

![snacks.nvim picker screenshot](https://github.com/user-attachments/assets/6eb06b7d-1330-4ec0-a8ea-e978b132d171)
_Screenshot is showing the Snacks picker._

## Features

- Browse and search Python standard library modules and project modules.
- Supports pickers:
  - Native Neovim picker (no preview)
  - [Telescope](https://github.com/nvim-telescope/telescope.nvim) picker with
    preview
  - [Snacks](https://github.com/folke/snacks.nvim) picker with preview

## Requirements

- Neovim >= 0.8.0
- Python installation with `python -m pydoc` command available
- Tree-sitter (for syntax highlighting)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "fredrikaverpil/pydoc.nvim",
    dependencies = {
        { "nvim-telescope/telescope.nvim" }, -- optional
        { "folke/snacks.nvim" }, -- optional
        {
            "nvim-treesitter/nvim-treesitter",
            opts = {
              ensure_installed = { "markdown" },
            },
        },
    },
    cmd = { "PyDoc" },
    opts = {},
}
```

## Usage

The plugin provides the following command:

- `:PyDoc` - Open picker and search packages.
- `:PyDoc <package>` - Directly open documentation for the specified package or
  symbol.

### Examples

```vim
:PyDoc                  " browse all standard library packages
:PyDoc strings          " view documentation for the strings package
:PyDoc strings.Builder  " view documentation for strings.Builder
```

```lua
local pydoc = require("pydoc.nvim")
pydoc.show_native_picker()  -- search packages using the native Neovim picker
pydoc.show_telescope_picker()  -- search packages using the telescope picker
pydoc.show_snacks_picker()  -- search packages using the Snacks.nvim picker
pydoc.get_documentation("time")  -- get the pydoc for the 'time' module
pydoc.show_documentation("time")  -- view docs for the 'time' module in split
```

## Configuration

These are the defaults:

```lua
opts = {
    command = "PyDoc", -- the desired Vim command to use
    window = {
        type = "split", -- split or vsplit
    },
    highlighting = {
        language = "markdown", -- the tree-sitter parser used for syntax highlighting
    },
    picker = {
        type = "native", -- native, telescope or snacks
        snacks_options = {
            layout = {
                layout = {
                    height = 0.8,
                    width = 0.9, -- Take up 90% of the total width (adjust as needed)
                    box = "horizontal", -- Horizontal layout (input and list on the left, preview on the right)
                    { -- Left side (input and list)
                        box = "vertical",
                        width = 0.3, -- List and input take up 30% of the width
                        border = "rounded",
                        { win = "input", height = 1, border = "bottom" },
                        { win = "list", border = "none" },
                    },
                    { win = "preview", border = "rounded", width = 0.7 }, -- Preview window takes up 70% of the width
                },
            },
            win = {
                preview = {
                    wo = { wrap = true },
                },
            },
        },
    },
}
```

## Contributing

Contributions are welcome! Please feel free to submit a pull request.

I would be extra interested in discussions and contributions around improving
the syntax highlighting of `python -m pydoc` output, as it is currently quite
"busy", when applying the syntax highlighting of markdown syntax.

I'm also wondering if `pydoc` is the best tool to output documentation to begin
with.
