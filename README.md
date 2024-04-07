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
- create, copy, move, rename & delete
...by just editing the current tree view buffer:

https://github.com/JonasLeonhard/broil/assets/54074887/2bd63166-434f-4a2c-8e22-539e2ce868d2

- run any terminal command like touch, mkdir, ls, chmod and see the output

https://github.com/JonasLeonhard/broil/assets/54074887/18c71a52-4862-4e93-9082-d288853f71c2

## Content Search

https://github.com/JonasLeonhard/broil/assets/54074887/850e35d5-81e7-411e-8ad1-7b21f0331885

## Motions:
- gg and g
- C-j, C-k, j, k - movement
- C-l or CR - Open selected
- C-h - go dir up

## Settings
- Change the search mode (fuzzy searching via file/dir names, or by file contents)
- show / hide hidden dot files and directories
- Sorting by dir_first
- Sorting by files_first
- Sorting alphabetically (TODO)
- Sorting by size (TODO)
- Fuzzy case mode (smart_case, ignore_case, respect_case)
- Toggle Fuzzy Search

https://github.com/JonasLeonhard/broil/assets/54074887/02f523ba-8964-4785-8bff-9d2f809bb63e


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
    rm_command = 'rm', -- optional...(default 'rm'). you could use a trash command here. Or rm --trash for nushell...
    -- ... you can find more opts in lua/broil/config.lua
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

# License


