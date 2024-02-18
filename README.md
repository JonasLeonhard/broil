# Broil = Broot + Oil


# TODOs:

# Refactor / Fix :
- save node path as plenary paths more functions to handle paths eg: to make paths relative. https://github.com/nvim-lua/plenary.nvim/blob/4f71c0c4a196ceb656c824a70792f3df3ce6bb6d/lua/plenary/path.lua#L92 
- remove tree.filtered_nodes
- stop async tree:build coroutine when running build again. Or atleast dont make it rerender twice (maybe add a build counter increment?)
- render tree like broot ui with virtual text or extmarks?
- fuzzy highlight what matched
- display directory children like broot "x unlisted..."

# Motions:
- <C-u> and <C-d> motion
- <C-g> goto root, top, bot, parent_node...

# Infos:
- after opening, select current file

- select best fuzzy find hightlight with score: maybe use https://github.com/nvim-telescope/telescope-fzf-native.nvim ?
- better tree visualization
- help bar above search like in broot
- show file chmod, size
- order by size, name, permissions, owner, last-edited ...
- open dir in terminal?
- git integration (edited, changed...)

# Syncing:
- create
- move
- rename
- delete
