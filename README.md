# Broil
Fuzzy Search your directory tree.

⚠️ This Plugin is in Beta. So expect stuff to not 100% work and expect breaking changes at any point.
tested on: Latest master branch version of neovim, (Macos & Linux)

# Features

## Tree View & Fuzzy Search
Fuzzy search using using <a href="https://github.com/nvim-telescope/telescope-fzf-native.nvim?tab=readme-ov-file#telescope-fzf-nativenvim">telescope-fzf-native</a>:

https://github.com/JonasLeonhard/broil/assets/54074887/5a9400a9-624c-4c60-9740-5b9e7082e85c

Broil supports the fzf syntax of telescope-fzf-native:
...From their readme: **fzf-native** is a `c` port of **[fzf][fzf]**. It only covers the algorithm and
implements few functions to support calculating the score.

This means that the [fzf syntax](https://github.com/junegunn/fzf#search-syntax)
is supported:

| Token     | Match type                 | Description                          |
| --------- | -------------------------- | ------------------------------------ |
| `sbtrkt`  | fuzzy-match                | Items that match `sbtrkt`            |
| `'wild`   | exact-match (quoted)       | Items that include `wild`            |
| `^music`  | prefix-exact-match         | Items that start with `music`        |
| `.mp3$`   | suffix-exact-match         | Items that end with `.mp3`           |
| `!fire`   | inverse-exact-match        | Items that do not include `fire`     |
| `!^music` | inverse-prefix-exact-match | Items that do not start with `music` |
| `!.mp3$`  | inverse-suffix-exact-match | Items that do not end with `.mp3`    |

## Toggle Open Directory to your File explorer

Do you want to edit the current tree directory? You can press Ctrl-z to switch the current directory tree-view to netrw (or any other file explorer like Oil - see config.netrw_command).

## Terminal Commands

- run any terminal command like touch, mkdir, ls, chmod and see the output

Some chars combinations in the terminal mode get autofilled:
- "%<space>" = path of the currently selected node
- "%n<space>" = name of the currently selected node
- ".<space>" = path of the currently opened tree view

https://github.com/JonasLeonhard/broil/assets/54074887/18c71a52-4862-4e93-9082-d288853f71c2

## Content Search

Search by filecontents using regex that would work in vims string:find('yoursearch')

https://github.com/JonasLeonhard/broil/assets/54074887/e2cabe68-4648-447b-bc28-ff65a628c22f

## Settings
- Change the search mode (fuzzy searching via file/dir names, or by file contents in the current tree dir)
- show / hide hidden dot files and directories
- Sorting by type
- Sorting alphabetically
- Sorting by size
- Sorting by children_count
- Sort the above (sort order) ascending and descending
- Fuzzy case mode (smart_case, ignore_case, respect_case)
- Toggle Fuzzy Search

## default Keybindy:
- gg and g
- C-j, C-k, j, k, C-u, C-d - movement & scrolling
- C-l or CR - Open selected
- C-h - go dir up
- C-w k - change window up
- C-w j - change window down
- C-w l - change window right
- C-w h - change window left
- C-q - close window
- ":" in search prompt to run shell command
- C-c show config
- C-z toggle between netrw & broil view.

# Configuration

<details>
  <summary>Lazy</summary>

```lua
return {
  'JonasLeonhard/broil',
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      cond = function()
        return vim.fn.executable 'make' == 1
      end,
      build =
      'make'
    }
  },
  opts = {
    -- ... you can find more opts in ":h broil" or lua/broil/config.lua
    -- netrw_command = "Oil " -- this switches the current tree-view to netrw
    -- if you are using Oil: add this <Ctrl-z> keybind to the oil configuration to switch back to broils tree-view:
    -- -- in oil.nvim keymaps
    -- ["<C-z>"] = {
    --   desc = "Toggle Broil",
    --   callback = function()
    --     local oil = require("oil");
    --     local broil = require("broil")
    --     local current_dir = oil.get_current_dir()
    --     oil.close()
    --     broil.open(current_dir)
    --   end
    -- }
  },
  keys = {
    {
      '<leader>o',
      "<cmd>lua require('broil').open()<cr>", -- opens current %:h or cwd by default
      desc = 'Broil open',
    },
    {
      '<leader>O',
      "<cmd>lua require('broil').open(vim.fn.getcwd())<cr>",
      desc = 'Broil open cwd',
    },
  }
}
```
</details>

# Highlights

Want your own color Scheme?
```lua
-- highlights (set these after broil init was already called)
vim.api.nvim_command("highlight BroilPreviewMessageFillchar guifg=#585b70")
vim.api.nvim_command("highlight BroilPreviewMessage guifg=#b4befe")
vim.api.nvim_command("highlight BroilSearchTerm guifg=#f9e2af")
vim.api.nvim_command("highlight BroilDirLine guifg=#89b4fa")
vim.api.nvim_command("highlight BroilPruningLine guifg=#a6adc8")
vim.api.nvim_command("highlight BroilRelativeLine guifg=#74c7ec")
vim.api.nvim_command("highlight BroilInactive guifg=#a6adc8")
vim.api.nvim_command("highlight BroilActive guifg=#f2cdcd")
vim.api.nvim_command("highlight BroilSearchIcon guifg=#bac2de")
```

# Contributing
Want to help me make this plugin better? Create a pull request!

# License
MIT

