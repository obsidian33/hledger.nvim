local Helpers = {}

--- A child Neovim restarted with the plugin before each test case.
---@return table child, table set
function Helpers.new_child_set()
    local child = MiniTest.new_child_neovim()
    local set = MiniTest.new_set({
        hooks = {
            pre_case = function()
                child.restart({ "-u", "scripts/minimal_init.lua" })
            end,
            post_once = child.stop,
        },
    })
    return child, set
end

--- Opens a scratch buffer with the given filetype and lines, with the cursor at
--- `cursor` ({row, col}, 1-based row).
---@param child table
---@param filetype string
---@param lines string[]
---@param cursor? integer[]
function Helpers.buffer(child, filetype, lines, cursor)
    child.cmd("enew")
    child.api.nvim_buf_set_lines(0, 0, -1, true, lines)
    child.bo.filetype = filetype
    child.api.nvim_win_set_cursor(0, cursor or { 1, 0 })
end

---@param child table
---@return string[]
function Helpers.lines(child)
    return child.api.nvim_buf_get_lines(0, 0, -1, true)
end

return Helpers
