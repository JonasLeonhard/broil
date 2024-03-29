# Broil = Broot + Oil
Navigate Directories like <a href="https://github.com/Canop/broot" target="_blank">Broot</a>,
and edit like <a href="https://github.com/stevearc/oil.nvim">Oil</a>.


![Open and search](https://github.com/JonasLeonhard/broil/assets/54074887/f14fb934-75df-4ab8-91ec-88380b60fd1d)

# Features

Fuzzy search using using <a href="https://github.com/nvim-telescope/telescope-fzf-native.nvim?tab=readme-ov-file#telescope-fzf-nativenvim">telescope-fzf-native</a>:

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

## Syncing:
- create
- move
- rename
- delete
- terminal command

## Motions:
- gg and g
- C-j, C-k, j, k - movement
- C-l or CR - Open selected
- C-h - go dir up

## Settings
- Sorting by dir_first (TODO)
- Sorting by files_first (TODO)
- Sorting alphabetically (TODO)
- Sorting by size (TODO)

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


