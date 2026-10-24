local M = {}

-- Lines that only start an hledger rules file: directives, a fields list,
-- field assignments and if blocks or tables
local RULES_LINE = {
    "^fields[%s:]",
    "^if[%s%p]",
    "^if$",
    "^skip[%s:]",
    "^skip$",
    "^source[%s:]",
    "^separator[%s:]",
    "^date%-format[%s:]",
    "^decimal%-mark[%s:]",
    "^newest%-first",
    "^include%s",
    "^account%d+[%s:]",
    "^amount[%d%-]*[%s:]",
    "^description[%s:]",
    "^currency[%s:]",
}

---@param lines string[]
---@return boolean
local function looks_like_rules(lines)
    for _, line in ipairs(lines) do
        for _, pattern in ipairs(RULES_LINE) do
            if line:find(pattern) then
                return true
            end
        end
    end
    return false
end

--- Filetype for a `.rules` file. Neovim's own detection handles udev, ufw and
--- polkit rules by location, and everything else becomes "hog". hledger rules
--- files are usually named `FILE.csv.rules`; other `.rules` files are hledger
--- rules if their first lines look like it.
---@param path string
---@param bufnr? integer absent when matching a file name alone
---@return string?
function M.rules(path, bufnr)
    local detect = require("vim.filetype.detect")
    local builtin = detect.rules(path)
    if builtin ~= "hog" then
        return builtin
    end
    if path:lower():find("%.[cst]sv%.rules$") then
        return "hledger_rules"
    end
    if bufnr and looks_like_rules(vim.api.nvim_buf_get_lines(bufnr, 0, 30, false)) then
        return "hledger_rules"
    end
    return builtin
end

return M
