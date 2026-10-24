if vim.b.did_ftplugin then
    return
end
vim.b.did_ftplugin = true

vim.bo.commentstring = "; %s"
vim.bo.comments = "b:;,b:#"

-- Use tree-sitter-hledger when its parser is installed, as Neovim's own
-- filetype plugins do for their bundled parsers
if vim.treesitter.language.add("hledger_rules") then
    vim.treesitter.start()
end

vim.b.undo_ftplugin = "setlocal commentstring< comments<\n call v:lua.vim.treesitter.stop()"
