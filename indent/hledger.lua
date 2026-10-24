if vim.b.did_indent then
    return
end
vim.b.did_indent = true

vim.bo.autoindent = true
vim.bo.indentexpr = "v:lua.require'hledger.indent'.expr()"

vim.b.undo_indent = "setlocal autoindent< indentexpr<"
