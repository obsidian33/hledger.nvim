if vim.g.loaded_hledger then
    return
end
vim.g.loaded_hledger = true

-- Everything here loads the plugin's modules only when used.

vim.keymap.set("n", "<Plug>(hledger-secondary-date)", function()
    require("hledger").set_secondary_date()
end, { desc = "hledger: set the transaction's secondary date to today" })

vim.keymap.set("n", "<Plug>(hledger-cycle-status)", function()
    require("hledger").cycle_status()
end, { desc = "hledger: cycle the status mark (unmarked, pending, cleared)" })

vim.keymap.set("n", "<Plug>(hledger-fold-sections)", function()
    require("hledger").fold_sections()
end, { desc = "hledger: fold to the * sections" })

vim.keymap.set("i", "<Plug>(hledger-align-amount)", function()
    return require("hledger").align_amount() or "\t"
end, { expr = true, desc = "hledger: move to the amount column, or insert a tab" })

--- The sorted keys of `tbl` that start with `lead`, for completion
---@param tbl table<string, any>
---@param lead string
---@return string[]
local function matching(tbl, lead)
    local keys = vim.tbl_filter(function(s)
        return vim.startswith(s, lead)
    end, vim.tbl_keys(tbl))
    table.sort(keys)
    return keys
end

---@class hledger.Subcommand
---@field impl fun(args: string[])
---@field complete? fun(arg_lead: string): string[]

local STATUSES = { cleared = "*", pending = "!", unmarked = "" }

---@type table<string, hledger.Subcommand>
local subcommands = {
    ["secondary-date"] = {
        -- :Hledger secondary-date [YYYY-MM-DD]
        impl = function(args)
            local time
            if args[1] then
                local y, m, d = args[1]:match("^(%d%d%d%d)[-/.](%d%d?)[-/.](%d%d?)$")
                local date = y and { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }
                time = date and os.time(date)
                -- os.time() quietly turns 2026-02-31 into March 3
                local actual = time and os.date("*t", time) --[[@as osdate?]]
                if not (actual and actual.year == date.year and actual.month == date.month and actual.day == date.day) then
                    vim.notify("hledger: expected a valid date like 2026-01-31", vim.log.levels.ERROR)
                    return
                end
            end
            require("hledger").set_secondary_date(time)
        end,
    },
    ["fold-sections"] = {
        impl = function()
            require("hledger").fold_sections()
        end,
    },
    status = {
        -- :Hledger status [cleared|pending|unmarked], or cycle without an argument
        impl = function(args)
            if not args[1] then
                return require("hledger").cycle_status()
            end
            local status = STATUSES[args[1]]
            if not status then
                vim.notify("hledger: unknown status " .. args[1], vim.log.levels.ERROR)
                return
            end
            require("hledger").set_status(status)
        end,
        complete = function(arg_lead)
            return matching(STATUSES, arg_lead)
        end,
    },
}

vim.api.nvim_create_user_command("Hledger", function(opts)
    local name = opts.fargs[1]
    local subcommand = subcommands[name]
    if not subcommand then
        vim.notify("hledger: unknown subcommand " .. tostring(name), vim.log.levels.ERROR)
        return
    end
    subcommand.impl(vim.list_slice(opts.fargs, 2))
end, {
    nargs = "+",
    desc = "hledger commands",
    complete = function(arg_lead, cmdline)
        local name, sub_lead = cmdline:match("^%S+%s+(%S+)%s+(.*)$")
        if name then
            local subcommand = subcommands[name]
            return subcommand and subcommand.complete and subcommand.complete(sub_lead) or {}
        end
        return matching(subcommands, arg_lead)
    end,
})
