---@brief
--- Lua API of hledger.nvim. Every function works on the current buffer.

local M = {}

---@param msg string
local function warn(msg)
    vim.notify("hledger: " .. msg, vim.log.levels.WARN)
end

---@return integer bufnr
---@return integer row 0-based cursor line
local function cursor()
    return vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1] - 1
end

---@param bufnr integer
---@param node TSNode
---@param text string
local function replace(bufnr, node, text)
    local sr, sc, er, ec = node:range()
    vim.api.nvim_buf_set_text(bufnr, sr, sc, er, ec, { text })
end

---@param bufnr integer
---@param row integer
---@param col integer
---@param text string
local function insert(bufnr, row, col, text)
    vim.api.nvim_buf_set_text(bufnr, row, col, row, col, { text })
end

--- Sets the secondary date of the transaction under the cursor, replacing any
--- existing one. The date uses the same separator as the primary date.
---@param time? integer the date to set, as a timestamp; defaults to today
function M.set_secondary_date(time)
    local journal = require("hledger.journal")
    local bufnr, row = cursor()
    local entry, err = journal.entry_at(bufnr, row)
    if not entry then
        return warn(err --[[@as string]])
    end
    local date = journal.field(entry.transaction, "date")
    if not date then
        return warn("only transactions have dates")
    end
    local sep = vim.treesitter.get_node_text(date, bufnr):match("[-/.]") or "-"
    local formatted = os.date(("%%Y%s%%m%s%%d"):format(sep, sep), time) --[[@as string]]

    local secondary = journal.field(entry.transaction, "secondary_date")
    if secondary then
        replace(bufnr, secondary, formatted)
    else
        local _, _, er, ec = date:range()
        insert(bufnr, er, ec, "=" .. formatted)
    end
end

---@alias hledger.Status "*" | "!" | ""

--- The posting or transaction whose status the cursor's line holds.
---@return integer? bufnr
---@return hledger.Entry? entry
---@return TSNode? owner
local function status_owner()
    local journal = require("hledger.journal")
    local bufnr, row = cursor()
    local entry, err = journal.entry_at(bufnr, row)
    if not entry then
        warn(err --[[@as string]])
        return
    end
    if not (entry.posting or entry.header) then
        warn("move the cursor to a posting or the transaction's first line")
        return
    end
    return bufnr, entry, entry.posting or entry.transaction
end

--- Sets the status mark of the posting under the cursor, or of the transaction
--- if the cursor is on its first line: `*` cleared, `!` pending, `""` unmarked.
---@param status hledger.Status
function M.set_status(status)
    vim.validate("status", status, function(s)
        return s == "*" or s == "!" or s == ""
    end, '"*", "!" or ""')

    local journal = require("hledger.journal")
    local bufnr, entry, owner = status_owner()
    if not (bufnr and entry and owner) then
        return
    end
    local current = journal.field(owner, "status")

    if current then
        local sr, sc, er, ec = current:range()
        if status ~= "" then
            vim.api.nvim_buf_set_text(bufnr, sr, sc, er, ec, { status })
            return
        end
        -- Remove the mark and the space after it
        local line = vim.api.nvim_buf_get_lines(bufnr, er, er + 1, true)[1]
        local spaces = #(line:sub(ec + 1):match("^%s*"))
        vim.api.nvim_buf_set_text(bufnr, sr, sc, er, ec + spaces, {})
    elseif status ~= "" then
        if entry.posting then
            local sr, sc = entry.posting:range()
            insert(bufnr, sr, sc, status .. " ")
        else
            -- After the date (and secondary date) of a transaction, or the
            -- period expression of a periodic transaction
            local anchor = journal.field(owner, "secondary_date")
                or journal.field(owner, "date")
                or journal.field(owner, "period")
            if not anchor then
                return warn("auto posting rules have no status")
            end
            local _, _, er, ec = anchor:range()
            insert(bufnr, er, ec, (owner:type() == "periodic_transaction" and "  " or " ") .. status)
        end
    end
end

--- Moves the status of the posting or transaction under the cursor to the next
--- one: unmarked → pending (`!`) → cleared (`*`) → unmarked.
function M.cycle_status()
    local bufnr, _, owner = status_owner()
    if not (bufnr and owner) then
        return
    end
    local current = require("hledger.journal").field(owner, "status")
    local text = current and vim.treesitter.get_node_text(current, bufnr) or ""
    local next_status = ({ [""] = "!", ["!"] = "*", ["*"] = "" })[text]
    M.set_status(next_status)
end

--- For an insert-mode Tab mapping: asks the buffer's language servers for the
--- spaces that move the cursor to the amount column (an on-type formatting
--- request for a tab, which hledger-lsp answers). Returns the spaces to type,
--- or false when no server offers any, so the caller can fall back to a
--- normal Tab.
---
--- Typing the spaces, rather than applying an edit later, keeps them in order
--- with keys already queued, as when typing fast or replaying a macro.
---@return string|false
function M.align_amount()
    if vim.bo.filetype ~= "hledger" then
        return false
    end
    local bufnr = vim.api.nvim_get_current_buf()
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/onTypeFormatting" })) do
        local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
        ---@diagnostic disable-next-line: inject-field
        params.ch = "\t"
        ---@diagnostic disable-next-line: inject-field
        params.options = {
            tabSize = vim.lsp.util.get_effective_tabstop(bufnr),
            insertSpaces = vim.bo[bufnr].expandtab,
        }
        local resp = client:request_sync("textDocument/onTypeFormatting", params, 500, bufnr)
        local edits = resp and resp.result or {}
        local edit = edits[1]
        -- Only a single insertion of spaces at the cursor can be typed
        if
            #edits == 1
            and edit.newText:match("^ +$")
            and vim.deep_equal(edit.range.start, params.position)
            and vim.deep_equal(edit.range["end"], params.position)
        then
            return edit.newText
        end
    end
    return false
end

--- A 'foldexpr' for journals and rules files: tree-sitter folds (sections,
--- transactions, if blocks, ...) where tree-sitter is running, and otherwise
--- folds for `*` outline headings. The filetype plugins set it.
---@param lnum? integer defaults to |v:lnum|
---@return string
function M.foldexpr(lnum)
    return require("hledger.folds").foldexpr(lnum)
end

--- A 'foldtext': the fold's first line and its number of lines, such as
--- `* Groceries [12 lines]`.
---@return string
function M.foldtext()
    return require("hledger.folds").foldtext()
end

--- Folds the current window down to its `*` sections: closes every section
--- and opens everything else (transactions, if blocks, ...).
function M.fold_sections()
    if vim.bo.filetype ~= "hledger" and vim.bo.filetype ~= "hledger_rules" then
        return warn("only journals and rules files have sections")
    end
    local folds = require("hledger.folds")
    folds.close_sections(vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf())
end

return M
