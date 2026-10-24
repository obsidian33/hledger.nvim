local M = {}

function M.check()
    local health = vim.health

    health.start("Neovim")
    if vim.fn.has("nvim-0.11") == 1 then
        health.ok("Neovim " .. tostring(vim.version()))
    else
        health.error("hledger.nvim needs Neovim 0.11 or later")
    end

    health.start("Filetype detection")
    for name, expected in pairs({ ["main.journal"] = "hledger", ["bank.csv.rules"] = "hledger_rules" }) do
        local ft = vim.filetype.match({ filename = name })
        if ft == expected then
            health.ok(("%s is detected as %s"):format(name, expected))
        else
            health.warn(("%s is detected as %s, not %s"):format(name, tostring(ft), expected), {
                "Another plugin or your config may override the filetype",
            })
        end
    end

    health.start("Tree-sitter parsers (tree-sitter-hledger)")
    for _, lang in ipairs({ "hledger", "hledger_rules" }) do
        if vim.treesitter.language.add(lang) then
            health.ok(lang .. " is installed")
        else
            health.warn(lang .. " isn't installed", {
                "Highlighting, folds and the editing commands need it",
                "See :help hledger-tree-sitter",
            })
        end
    end

    health.start("hledger")
    if vim.fn.executable("hledger") == 1 then
        local out = vim.system({ "hledger", "--version" }, { text = true }):wait()
        health.ok(vim.trim(out.stdout or "hledger"))
    else
        health.info("hledger isn't on PATH; nothing needs it yet")
    end
end

return M
