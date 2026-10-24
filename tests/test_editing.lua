local Helpers = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality

local child, T = Helpers.new_child_set()

-- A fixed date, so results don't depend on the day the tests run
local OCT_24 = "os.time({ year = 2026, month = 10, day = 24, hour = 12 })"

local TRANSACTION = {
    "2026-10-01 * Whole Foods",
    "    expenses:groceries  $82.40",
    "    assets:checking",
}

T["set_secondary_date()"] = MiniTest.new_set()

T["set_secondary_date()"]["adds a secondary date"] = function()
    Helpers.buffer(child, "hledger", TRANSACTION)
    child.lua("require('hledger').set_secondary_date(" .. OCT_24 .. ")")
    eq(Helpers.lines(child)[1], "2026-10-01=2026-10-24 * Whole Foods")
end

T["set_secondary_date()"]["uses the primary date's separator"] = function()
    Helpers.buffer(child, "hledger", { "2026/10/01 coffee", "    a  1", "    b" })
    child.lua("require('hledger').set_secondary_date(" .. OCT_24 .. ")")
    eq(Helpers.lines(child)[1], "2026/10/01=2026/10/24 coffee")
end

T["set_secondary_date()"]["replaces an existing secondary date"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01=2026-10-05 x", "    a  1", "    b" })
    child.lua("require('hledger').set_secondary_date(" .. OCT_24 .. ")")
    eq(Helpers.lines(child)[1], "2026-10-01=2026-10-24 x")
end

T["set_secondary_date()"]["works from a posting line"] = function()
    Helpers.buffer(child, "hledger", TRANSACTION, { 3, 0 })
    child.lua("require('hledger').set_secondary_date(" .. OCT_24 .. ")")
    eq(Helpers.lines(child)[1], "2026-10-01=2026-10-24 * Whole Foods")
end

T["set_secondary_date()"]["leaves lines outside transactions alone"] = function()
    Helpers.buffer(child, "hledger", { "account assets:checking", "" })
    child.lua("require('hledger').set_secondary_date(" .. OCT_24 .. ")")
    eq(Helpers.lines(child), { "account assets:checking", "" })
end

T["set_status()"] = MiniTest.new_set()

T["set_status()"]["marks a transaction"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 Rent", "    a  1", "    b" })
    child.lua("require('hledger').set_status('!')")
    eq(Helpers.lines(child)[1], "2026-10-01 ! Rent")
end

T["set_status()"]["changes a transaction's mark"] = function()
    Helpers.buffer(child, "hledger", TRANSACTION)
    child.lua("require('hledger').set_status('!')")
    eq(Helpers.lines(child)[1], "2026-10-01 ! Whole Foods")
end

T["set_status()"]["unmarks a transaction"] = function()
    Helpers.buffer(child, "hledger", TRANSACTION)
    child.lua("require('hledger').set_status('')")
    eq(Helpers.lines(child)[1], "2026-10-01 Whole Foods")
end

T["set_status()"]["marks the posting under the cursor"] = function()
    Helpers.buffer(child, "hledger", TRANSACTION, { 3, 0 })
    child.lua("require('hledger').set_status('*')")
    eq(Helpers.lines(child), {
        "2026-10-01 * Whole Foods",
        "    expenses:groceries  $82.40",
        "    * assets:checking",
    })
end

T["set_status()"]["unmarks a posting"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 x", "    ! a  1", "    b" }, { 2, 0 })
    child.lua("require('hledger').set_status('')")
    eq(Helpers.lines(child)[2], "    a  1")
end

T["set_status()"]["marks a periodic transaction"] = function()
    Helpers.buffer(child, "hledger", { "~ monthly  rent", "    a  1", "    b" })
    child.lua("require('hledger').set_status('*')")
    eq(Helpers.lines(child)[1], "~ monthly  *  rent")
end

T["set_status()"]["rejects unknown marks"] = function()
    Helpers.buffer(child, "hledger", TRANSACTION)
    MiniTest.expect.error(function()
        child.lua("require('hledger').set_status('x')")
    end)
end

T["set_status()"]["leaves comment lines inside a transaction alone"] = function()
    local lines = { "2026-10-01 Rent", "    ; paid by transfer", "    a  1", "    b" }
    Helpers.buffer(child, "hledger", lines, { 2, 0 })
    child.lua("require('hledger').set_status('*')")
    eq(Helpers.lines(child), lines)
end

T["cycle_status()"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 Rent", "    a  1", "    b" })
    local seen = {}
    for _ = 1, 3 do
        child.lua("require('hledger').cycle_status()")
        table.insert(seen, Helpers.lines(child)[1])
    end
    eq(seen, { "2026-10-01 ! Rent", "2026-10-01 * Rent", "2026-10-01 Rent" })
end

T["align_amount()"] = MiniTest.new_set()

T["align_amount()"]["returns false without a language server"] = function()
    Helpers.buffer(child, "hledger", TRANSACTION)
    eq(child.lua_get("require('hledger').align_amount()"), false)
end

--- Starts a language server inside the child that answers on-type formatting
--- requests with `edit(params)`, written as Lua source.
---@param edit string
local function fake_server(edit)
    child.lua(
        [[
        local edit = loadstring("return function(params) return " .. ... .. " end")()
        local id = vim.lsp.start({
            name = "fake",
            cmd = function()
                return {
                    request = function(method, params, callback)
                        if method == "initialize" then
                            callback(nil, { capabilities = {
                                documentOnTypeFormattingProvider = { firstTriggerCharacter = "\n" },
                            } })
                        elseif method == "textDocument/onTypeFormatting" then
                            callback(nil, edit(params))
                        else
                            callback(nil, nil)
                        end
                        return true, 1
                    end,
                    notify = function() return true end,
                    is_closing = function() return false end,
                    terminate = function() end,
                }
            end,
        })
        vim.wait(1000, function() return vim.lsp.get_client_by_id(id).initialized end)
    ]],
        { edit }
    )
end

T["align_amount()"]["types the spaces a server inserts at the cursor"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 x", "    a" }, { 2, 5 })
    fake_server("{ { range = { start = params.position, ['end'] = params.position }, newText = '   ' } }")
    eq(child.lua_get("require('hledger').align_amount()"), "   ")
end

T["align_amount()"]["ignores edits elsewhere"] = function()
    Helpers.buffer(child, "hledger", { "2026-10-01 x", "    a" }, { 2, 5 })
    fake_server(
        "{ { range = { start = { line = 1, character = 0 }, ['end'] = { line = 1, character = 4 } }, newText = '  ' } }"
    )
    eq(child.lua_get("require('hledger').align_amount()"), false)
end

T["align_amount()"]["returns false outside journals"] = function()
    Helpers.buffer(child, "lua", { "local x" })
    eq(child.lua_get("require('hledger').align_amount()"), false)
end

return T
