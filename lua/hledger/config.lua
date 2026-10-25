---@class hledger.Opts
--- Start journals and rules files with only their `*` sections folded.
---@field fold_sections_on_open? boolean

---@class hledger.Config
---@field fold_sections_on_open boolean

local M = {}

---@type hledger.Config
local DEFAULTS = {
    fold_sections_on_open = false,
}

--- The settings in |g:hledger| over the defaults, and an error message when
--- they're invalid (the defaults are used then).
---@return hledger.Config config
---@return string? err
function M.get()
    local opts = vim.g.hledger
    if opts == nil then
        return vim.deepcopy(DEFAULTS)
    end
    local ok, err = pcall(function()
        vim.validate("vim.g.hledger", opts, "table")
        vim.validate("vim.g.hledger.fold_sections_on_open", opts.fold_sections_on_open, "boolean", true)
        for key in pairs(opts) do
            if DEFAULTS[key] == nil then
                error(("vim.g.hledger: unknown option %q"):format(key), 0)
            end
        end
    end)
    if not ok then
        return vim.deepcopy(DEFAULTS), tostring(err)
    end
    return vim.tbl_extend("force", DEFAULTS, opts)
end

return M
