if vim.b.did_ftplugin then
    return
end
vim.b.did_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()

vim.bo.commentstring = "; %s"
vim.bo.comments = "b:;,b:#"
vim.bo.include = [[^\s*include]]

-- Use tree-sitter-hledger when its parser is installed, as Neovim's own
-- filetype plugins do for their bundled parsers
if vim.treesitter.language.add("hledger") then
    vim.treesitter.start()
end

require("hledger.folds").attach(bufnr)

vim.b.undo_ftplugin = "setlocal commentstring< comments< include< foldexpr<\n call v:lua.vim.treesitter.stop()\n lua require('hledger.folds').undo(" .. bufnr .. ")"
