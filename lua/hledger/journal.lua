-- Finding transactions and postings in a journal buffer with the hledger
-- tree-sitter parser (tree-sitter-hledger).

local M = {}

---@param bufnr integer
---@return vim.treesitter.LanguageTree?
local function parser(bufnr)
    local p = vim.treesitter.get_parser(bufnr, "hledger", { error = false })
    if p then
        p:parse()
    end
    return p
end

---@param node TSNode?
---@param types table<string, true>
---@return TSNode?
local function ancestor(node, types)
    while node and not types[node:type()] do
        node = node:parent()
    end
    return node
end

local TRANSACTIONS = { transaction = true, periodic_transaction = true, auto_posting_rule = true }

---@class hledger.Entry
---@field transaction TSNode the transaction, periodic transaction or auto posting rule
---@field header boolean whether the line is the transaction's first line
---@field posting TSNode? the posting on the line, if any

--- The transaction (or periodic transaction or auto posting rule) at a line,
--- and the posting on that line if there is one.
---@param bufnr integer
---@param row integer 0-based line
---@return hledger.Entry? entry
---@return string? err
function M.entry_at(bufnr, row)
    local p = parser(bufnr)
    if not p then
        return nil, "the hledger tree-sitter parser isn't installed (see :checkhealth hledger)"
    end
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]
    local col = math.max((line:find("%S") or 1) - 1, 0)
    local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col }, lang = "hledger" })
    local transaction = ancestor(node, TRANSACTIONS)
    if not transaction then
        return nil, "the cursor isn't on a transaction"
    end
    local entry = { transaction = transaction, header = transaction:start() == row }
    for child in transaction:iter_children() do
        if child:type() == "posting" and child:start() == row then
            entry.posting = child
        end
    end
    return entry
end

---@param node TSNode
---@param name string
---@return TSNode?
function M.field(node, name)
    return node:field(name)[1]
end

return M
