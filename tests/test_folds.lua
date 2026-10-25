local Helpers = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality

local child, T = Helpers.new_child_set()

local RULES = {
    "skip 1", --  1
    "if TOPLEVEL", --  2
    "  account2 expenses:misc", --  3
    "", --  4
    "* Setup", --  5
    "account1 assets:checking", --  6
    "** Empty", --  7
    "** Food", --  8
    "if WHOLE FOODS", --  9
    "  account2 expenses:groceries", -- 10
    "", -- 11
    "* Bills", -- 12
    "if NETFLIX", -- 13
    "  account2 expenses:subscriptions", -- 14
}

local JOURNAL = {
    "* 2026", --  1
    "2026-10-01 rent", --  2
    "    expenses:rent  $1000", --  3
    "    assets:checking", --  4
    "", --  5
    "2026-10-02 coffee", --  6
    "    expenses:coffee  $5", --  7
    "    assets:cash", --  8
}

--- Writes `lines` to a file with the given extension and opens it, so the
--- filetype is detected and the buffer is shown as a real file would be.
--- Waits for the child to make `check` (Lua source) true, letting it run its
--- scheduled and deferred fold work meanwhile. Waiting inside the child
--- (vim.wait in child.lua) would block it in an RPC request instead.
---@param check string
---@param timeout? integer
local function wait_until(check, timeout)
    local deadline = vim.uv.now() + (timeout or 3000)
    while not child.lua_get(check) and vim.uv.now() < deadline do
        vim.uv.sleep(20)
        vim.uv.update_time()
    end
end

local HAS_FOLDS = "(function() for l = 1, vim.fn.line('$') do if vim.fn.foldlevel(l) > 0 then return true end end return false end)()"
local SECTIONS_FOLDED = "next(vim.w.hledger_sections_folded or {}) ~= nil"

--- Writes `lines` to a file with the given extension and opens it, so the
--- filetype is detected and the buffer is shown as a real file would be.
--- Returns once the folds exist, and with `fold_sections_on_open`, once the
--- sections are closed.
---@param ext string
---@param lines string[]
local function open(ext, lines)
    local path = child.fn.tempname() .. ext
    child.fn.writefile(lines, path)
    child.cmd("edit " .. path)
    wait_until(HAS_FOLDS)
    if child.lua_get("type(vim.g.hledger) == 'table' and vim.g.hledger.fold_sections_on_open == true") then
        wait_until(SECTIONS_FOLDED)
    end
end

---@param lnum integer
---@return boolean
local function closed(lnum)
    return child.fn.foldclosed(lnum) ~= -1
end

T["foldexpr is set for both filetypes"] = function()
    Helpers.buffer(child, "hledger", { "" })
    eq(child.wo.foldexpr, "v:lua.require'hledger'.foldexpr()")
    Helpers.buffer(child, "hledger_rules", { "" })
    eq(child.wo.foldexpr, "v:lua.require'hledger'.foldexpr()")
end

T["folds are left alone by default"] = function()
    child.o.foldmethod = "expr"
    child.o.foldlevelstart = 99
    child.o.foldlevel = 99
    open(".rules", RULES)
    eq({ closed(5), closed(12) }, { false, false })
end

T["fold_sections_on_open"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.o.foldmethod = "expr"
            child.o.foldlevelstart = 99
            child.o.foldlevel = 99
            child.g.hledger = { fold_sections_on_open = true }
        end,
    },
})

T["fold_sections_on_open"]["closes only the sections of a rules file"] = function()
    open(".rules", RULES)
    eq(child.lua_get("vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil"), true)
    eq({ top_if = closed(2), setup = closed(5), bills = closed(12) }, { top_if = false, setup = true, bills = true })
    child.cmd("5foldopen")
    -- `** Empty` has no fold of its own; `** Food` is closed and its if block open
    eq({ empty = closed(7), food = closed(8) }, { empty = false, food = true })
    child.cmd("8foldopen")
    eq(closed(9), false)
end

T["fold_sections_on_open"]["leaves transactions open in journals"] = function()
    open(".journal", JOURNAL)
    eq(closed(1), true)
    child.cmd("1foldopen")
    eq({ closed(2), closed(6) }, { false, false })
end

T["fold_sections_on_open"]["keeps folds opened by hand"] = function()
    open(".rules", RULES)
    local buf = child.api.nvim_get_current_buf()
    child.cmd("5foldopen")
    child.cmd("enew")
    child.cmd("buffer " .. buf)
    vim.uv.sleep(200) -- give a wrongly scheduled refold the chance to run
    eq({ setup = closed(5), bills = closed(12) }, { setup = false, bills = true })
end

T["fold_sections_on_open"]["registers one autocommand per buffer"] = function()
    open(".rules", RULES)
    child.cmd("set filetype=hledger_rules")
    local count = "#vim.api.nvim_get_autocmds({ group = 'hledger_fold_sections', buffer = 0 })"
    eq(child.lua_get(count), 1)
    child.cmd("set filetype=text")
    eq(child.lua_get(count), 0)
end

T["fold_sections()"] = MiniTest.new_set()

T["fold_sections()"]["folds down to the sections"] = function()
    child.o.foldmethod = "expr"
    child.o.foldlevelstart = 0
    open(".rules", RULES)
    eq(closed(2), true)
    child.cmd("Hledger fold-sections")
    wait_until("vim.fn.foldclosed(5) ~= -1")
    eq({ top_if = closed(2), setup = closed(5) }, { top_if = false, setup = true })
end

T["fold_sections()"]["works without tree-sitter"] = function()
    child.o.foldmethod = "expr"
    child.o.foldlevelstart = 99
    child.o.foldlevel = 99
    open(".rules", RULES)
    child.lua("vim.treesitter.stop()")
    child.lua("require('hledger').fold_sections()")
    wait_until("vim.fn.foldclosed(5) ~= -1")
    eq({ setup = closed(5), food = closed(8), bills = closed(12) }, { setup = true, food = true, bills = true })
end

T["fold_sections()"]["warns outside journals and rules files"] = function()
    Helpers.buffer(child, "lua", { "local x = 1" })
    child.lua("vim.treesitter.start()")
    child.lua("require('hledger').fold_sections()")
    MiniTest.expect.no_equality(child.cmd_capture("messages"):find("only journals and rules files", 1, true), nil)
end

T["invalid settings"] = MiniTest.new_set()

T["invalid settings"]["warn and fall back to the defaults"] = function()
    child.o.foldmethod = "expr"
    child.o.foldlevelstart = 99
    child.o.foldlevel = 99
    child.g.hledger = { fold_sections_on_open = "yes" }
    open(".rules", RULES)
    eq(closed(5), false)
    local messages = child.cmd_capture("messages")
    MiniTest.expect.no_equality(messages:find("fold_sections_on_open", 1, true), nil)
end

T["invalid settings"]["report unknown options"] = function()
    child.g.hledger = { fold_section_on_open = true }
    local _, err = unpack(child.lua_get("{ require('hledger.config').get() }"))
    MiniTest.expect.no_equality(err:find("unknown option", 1, true), nil)
end

return T
