local M = {}

--- Indent for a new journal line: one level after a transaction, periodic (~)
--- or auto posting (=) header, or after any indented line (a posting or one of
--- its comments), and none after anything else. This matches how hledger reads
--- the lines, and works on the incomplete transaction being typed, which a
--- parse tree can't describe well yet.
---@return integer
function M.expr()
    local prev = vim.fn.getline(vim.v.lnum - 1)
    if prev:match("^[%d~=]") or prev:match("^%s+%S") then
        return vim.fn.shiftwidth()
    end
    return 0
end

return M
