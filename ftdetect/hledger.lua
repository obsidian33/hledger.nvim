vim.filetype.add({
    extension = {
        -- Neovim maps .journal to "ledger"; hledger reads these as journals
        journal = "hledger",
        hledger = "hledger",
        j = "hledger",
        rules = function(path, bufnr)
            return require("hledger.filetype").rules(path, bufnr)
        end,
    },
})
