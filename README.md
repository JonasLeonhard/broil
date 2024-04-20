# Broil = Broot + Oil
Navigate Directories like <a href="https://github.com/Canop/broot" target="_blank">Broot</a>,
and edit like <a href="https://github.com/stevearc/oil.nvim">Oil</a>.

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

## Cross Directory Buffer Editing:
~ NOTE: this feature is currently experimental and not quite stable, so make sure to look at the edits build from your buffer changes. This feature is not quite ironed out yet! ~

- create, copy, move, rename & delete
...by just editing the current tree view buffer:

https://github.com/JonasLeonhard/broil/assets/54074887/1f0843e6-03b7-4210-a0a9-cba2be84e4fd

your edits stay persistent across directories and searches, only you staged changes will get applied. And if you dont like them, you can undo them in a batch - or one by one:

https://github.com/JonasLeonhard/broil/assets/54074887/40439dad-6d9c-44a4-98a3-fd8e504124e7


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
- C-j, C-k, j, k - movement
- C-l or CR - Open selected
- C-h - go dir up
- C-w k - change window up
- C-w j - change window down
- C-w l - change window right
- C-w h - change window left
- C-q - close window
- ":" in search prompt to run shell command
- C-e show edits
- C-c show config

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
    -- rm_command = 'rm <FROM>', -- optional...(default 'rm'). you could use a trash command here. Or rm --trash for nushell...
    -- ... you can find more opts in ":h broil" or lua/broil/config.lua
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
  },
  enabled = true
}
```
</details>

# Contributing
Want to help me make this plugin better? Create a pull request!

# License
MIT

