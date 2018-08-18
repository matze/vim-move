# move

It's annoying to delete and paste parts of a text just to move it up/down or
left/right a bit.
There is the `:m[ove]` command but it is quite awkward to use by todays
standards. vim-move is a Vim plugin that moves lines and selections in a more
visual manner. Out of the box, the following keys are mapped in visual and
normal mode:

    <A-k>   Move current line/selection up
    <A-j>   Move current line/selection down
    <A-h>   Move current character/selection left
    <A-l>   Move current character/selection right

The mappings can be prefixed with a count, e.g. `5<A-k>` will move the selection
up by 5 lines.

See this short demo for a first impression:

![vim-vertical-move demo](http://i.imgur.com/RMv8KsJ.gif)

![vim-horizontal-move_demo](https://i.imgur.com/zKWEecp.gif)

## Installation

vim-move is compatible with all major plugin managers. To install it using
Vundle, add

```vim
Bundle 'matze/vim-move'
```

to your `.vimrc`.


## Customization

Use `g:move_key_modifier` to set a custom modifier for key bindings. For
example,

```vim
let g:move_key_modifier = 'C'
```

which will create the following key bindings:

    <C-k>   Move current line/selections up
    <C-j>   Move current line/selections down

And so on...

## License

This plugin is licensed under MIT license.
