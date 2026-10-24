local Helpers = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality

local child, T = Helpers.new_child_set()

T["indent"] = MiniTest.new_set()

T["indent"]["indents after a header and postings"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 x", "    a  1", "", "account a" })
    local function indent(lnum)
        return child.lua_get("(function() vim.v.lnum = " .. lnum .. "; return require('hledger.indent').expr() end)()")
    end
    eq(indent(2), child.lua_get("vim.fn.shiftwidth()"))
    eq(indent(3), child.lua_get("vim.fn.shiftwidth()"))
    eq(indent(4), 0)
end

T["indent"]["applies when typing"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 x" })
    child.type_keys("o", "expenses:food", "<Esc>")
    eq(child.fn.indent(2), child.lua_get("vim.fn.shiftwidth()"))
end

T["foldexpr() without tree-sitter folds star headings"] = function()
    Helpers.buffer(child, "hledger_rules", { "* Setup", "skip 1", "** Food", "if x", "  account2 y" })
    child.lua("vim.treesitter.stop()")
    local levels = child.lua_get(
        "vim.tbl_map(function(l) return require('hledger').foldexpr(l) end, { 1, 2, 3, 4, 5 })"
    )
    eq(levels, { ">1", "=", ">2", "=", "=" })
end

T[":Hledger"] = MiniTest.new_set()

T[":Hledger"]["status sets a mark"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 Rent", "    a  1", "    b" })
    child.cmd("Hledger status cleared")
    eq(Helpers.lines(child)[1], "2026-10-01 * Rent")
end

T[":Hledger"]["secondary-date takes a date"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 Rent", "    a  1", "    b" })
    child.cmd("Hledger secondary-date 2026-11-02")
    eq(Helpers.lines(child)[1], "2026-10-01=2026-11-02 Rent")
end

T[":Hledger"]["secondary-date rejects invalid dates"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 Rent", "    a  1", "    b" })
    MiniTest.expect.error(function()
        child.cmd("Hledger secondary-date 2026-02-31")
    end, "expected a valid date")
    eq(Helpers.lines(child)[1], "2026-10-01 Rent")
end

T[":Hledger"]["completes subcommands and statuses"] = function()
    eq(child.fn.getcompletion("Hledger s", "cmdline"), { "secondary-date", "status" })
    eq(child.fn.getcompletion("Hledger status c", "cmdline"), { "cleared" })
end

T["<Plug> mappings call the API"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 Rent", "    a  1", "    b" })
    child.cmd("nmap X <Plug>(hledger-cycle-status)")
    child.type_keys("X")
    eq(Helpers.lines(child)[1], "2026-10-01 ! Rent")
end

T[":checkhealth hledger runs"] = function()
    child.cmd("checkhealth hledger")
    local text = table.concat(child.api.nvim_buf_get_lines(0, 0, -1, true), "\n")
    MiniTest.expect.no_equality(text:find("hledger is installed"), nil)
end

return T
