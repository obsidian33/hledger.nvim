local Helpers = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality

local child, T = Helpers.new_child_set()

---@param filename string
---@param contents? string[]
local function detect(filename, contents)
    if contents then
        child.lua(
            "local buf = vim.api.nvim_create_buf(false, true); "
                .. "vim.api.nvim_buf_set_lines(buf, 0, -1, true, ...); _G.test_buf = buf",
            { contents }
        )
        return child.lua_get("vim.filetype.match({ filename = ..., buf = _G.test_buf })", { filename })
    end
    return child.lua_get("vim.filetype.match({ filename = ... })", { filename })
end

T["journals"] = function()
    eq(detect("main.journal"), "hledger")
    eq(detect("2026.hledger"), "hledger")
    eq(detect("t.j"), "hledger")
end

T["rules files named after their CSV"] = function()
    eq(detect("bank.csv.rules"), "hledger_rules")
    eq(detect("bank.tsv.rules"), "hledger_rules")
end

T["other rules files that look like hledger rules"] = function()
    eq(detect("bank.rules", { "# checking account", "skip 1", "fields date, description, amount" }), "hledger_rules")
    eq(detect("common.rules", { "if groceries", "  account2 expenses:groceries" }), "hledger_rules")
end

T["other rules files keep Neovim's detection"] = function()
    eq(detect("/etc/udev/rules.d/99-usb.rules"), "udevrules")
    eq(detect("snort.rules", { "alert tcp any any -> any 80 (msg:\"x\";)" }), "hog")
end

T["tree-sitter starts when the parser is installed"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 x", "    a  1", "    b" })
    eq(child.lua_get("vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil"), true)
    Helpers.buffer(child, "hledger_rules", { "skip 1" })
    eq(child.lua_get("vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil"), true)
end

T["filetype settings"] = function()
    Helpers.buffer(child, "hledger", { "" })
    eq(child.bo.commentstring, "; %s")
    eq(child.bo.indentexpr, "v:lua.require'hledger.indent'.expr()")
    Helpers.buffer(child, "hledger_rules", { "" })
    eq(child.bo.commentstring, "; %s")
end

return T
