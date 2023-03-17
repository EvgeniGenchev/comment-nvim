# comment-nvim

a simple lua script to help you comment and uncomment faster

![comment](https://user-images.githubusercontent.com/59848681/224585993-36bbde7a-c0c8-4b2e-8220-232b4ad26918.gif)

## Features

- Single line comment/uncomment
- Visual mode multi-line comment/uncomment
- Detecting languages and using the correct comment sign
- Remapable keymap shortcuts available

## Setup

- [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'EvgeniGenchev/comment-nvim'
```

- [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use({
  'EvgeniGenchev/comment-nvim',
})
```

## Usage
```lua
-- include the package in your init.lua
require('comment').setup()
```



## Customize

You can change the shortcuts of the commands.

```lua
-- Change the default singleline comment
vim.api.nvim_set_keymap('n', '?', ':Comment<CR>', {noremap=true, silent=false})

-- Change the visual mode multiline comment
vim.api.nvim_set_keymap('v', '?', ':CommentMore<CR>', {noremap=true, silent=false})
```

Also you can add other languages when you require the plug-in in `init.lua`.

```lua
require('comment').setup({
	languages = {
		sh = "#",
		php = "//",
		java = "//",
	},
})
```

## TODO

- [ ] add support for spaces
- [ ] add support for ranges in normal mod
- [ ] add support for multiline comment signes


<p align="center">
  Copyright &copy; 2023-present
  <a href="https://github.com/EvgeniGenchev" target="_blank">EvgeniGenchev</a>
</p>
<p align="center">
  <a href="https://github.com/EvgeniGenchev/comment-nvim/blob/master/LICENSE"
    ><img
      src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=MIT&logoColor=d9e0ee&colorA=282a36&colorB=c678dd"
  /></a>
</p>
