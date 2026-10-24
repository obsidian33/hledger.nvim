# hledger.nvim

Editing [hledger](https://hledger.org) journals and CSV rules files in Neovim.

- Filetypes: `hledger` for journals, `hledger_rules` for rules files, with
  comment, indent and `include` settings
- Commands to set a transaction's secondary date and cycle status marks
- Tab to the amount column with [hledger-lsp](https://github.com/juev/hledger-lsp)
- Folds for `*` outline headings, or tree-sitter folds where available

It needs no setup and sets no keymaps. Highlighting, folds and text objects
come from the [tree-sitter-hledger](https://github.com/obsidian33/tree-sitter-hledger)
parsers: install them (`:help hledger-tree-sitter`) and the plugin starts
tree-sitter in journals and rules files.

Requires Neovim 0.11 or later.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "obsidian33/hledger.nvim" }
```

The plugin loads its code only when it's used, so it needs no lazy-loading
configuration.

## Use

```vim
:Hledger secondary-date [YYYY-MM-DD]
:Hledger status [cleared|pending|unmarked]
```

Map the `<Plug>` mappings to keys you choose, for example in
`after/ftplugin/hledger.lua`:

```lua
vim.keymap.set("n", "<leader>ld", "<Plug>(hledger-secondary-date)", { buffer = true })
vim.keymap.set("n", "<leader>ls", "<Plug>(hledger-cycle-status)", { buffer = true })
```

See `:help hledger` for the tree-sitter parsers, folding, the Lua API and
using hledger-lsp, and `:checkhealth hledger` to see what's working.

## Development

Requires [just](https://just.systems) and the
[tree-sitter CLI](https://tree-sitter.github.io/tree-sitter/), which builds
the parsers the tests use.

```sh
just test                          # all tests
just test tests/test_editing.lua   # one file
```

Tests use [mini.test](https://github.com/nvim-mini/mini.test), driving a child
Neovim.

## License

MIT
