-- Folding journals and rules files: the fold expression, fold text, and
-- closing just the `*` sections.

local M = {}

local MAX_HEADING_LEVEL = 6

---@param bufnr integer
---@return boolean
local function treesitter_active(bufnr)
    return vim.treesitter.highlighter.active[bufnr] ~= nil
end

---@param lnum? integer
---@return string
function M.foldexpr(lnum)
    lnum = lnum or vim.v.lnum
    if treesitter_active(vim.api.nvim_get_current_buf()) then
        return vim.treesitter.foldexpr(lnum)
    end
    local stars = vim.fn.getline(lnum):match("^(%*+)%s")
    if stars and #stars <= MAX_HEADING_LEVEL then
        return ">" .. #stars
    end
    return "="
end

---@return string
function M.foldtext()
    local count = vim.v.foldend - vim.v.foldstart + 1
    return ("%s [%d lines]"):format(vim.fn.getline(vim.v.foldstart), count)
end

--- 0-based first rows of the multi-line sections, outermost first: from the
--- tree where tree-sitter folds (see |hledger.foldexpr()|), otherwise every
--- heading line, as the fallback folds them.
---@param bufnr integer
---@return integer[]
local function section_rows(bufnr)
    local rows = {}
    if treesitter_active(bufnr) then
        local parser = vim.treesitter.get_parser(bufnr)
        if not parser then
            return rows
        end
        local root = parser:parse()[1]:root()
        local query = vim.treesitter.query.parse(parser:lang(), "(section) @section")
        for _, node in query:iter_captures(root, bufnr) do
            local sr, _, er, ec = node:range()
            if (ec == 0 and er - 1 or er) > sr then
                table.insert(rows, sr)
            end
        end
    else
        for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
            local stars = line:match("^(%*+)%s")
            if stars and #stars <= MAX_HEADING_LEVEL then
                table.insert(rows, i - 1)
            end
        end
    end
    return rows
end

local RETRY_MS = 50
local RETRIES = 20

--- Closes the section folds in a window showing the buffer and opens the rest.
--- Tree-sitter computes fold levels after parsing, so this retries for a
--- moment while the window has no folds yet.
---@param win integer
---@param bufnr integer
---@param on_done? fun() called once the folds are closed
---@param tries? integer
function M.close_sections(win, bufnr, on_done, tries)
    tries = tries or RETRIES
    if not (vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr) then
        return
    end
    local rows = section_rows(bufnr)
    vim.api.nvim_win_call(win, function()
        -- Recompute the folds, which may be stale, for example after
        -- tree-sitter stopped
        vim.cmd("normal! zX")
        if #rows > 0 and vim.fn.foldlevel(rows[1] + 1) == 0 then
            if tries > 0 then
                vim.defer_fn(function()
                    M.close_sections(win, bufnr, on_done, tries - 1)
                end, RETRY_MS)
            end
            return
        end
        -- Unlike zR, leaves 'foldlevel' alone
        vim.cmd("silent! %foldopen!")
        -- Innermost sections first, so each heading closes its own fold
        for i = #rows, 1, -1 do
            pcall(vim.cmd, (rows[i] + 1) .. "foldclose")
        end
        if on_done then
            on_done()
        end
    end)
end

local GROUP = "hledger_fold_sections"

--- Closes the sections the first time each window shows the buffer, for
--- |g:hledger| `fold_sections_on_open`. Once per window, so folds opened by
--- hand stay open when the buffer comes back.
---@param bufnr integer
function M.fold_sections_on_open(bufnr)
    local group = vim.api.nvim_create_augroup(GROUP, { clear = false })
    vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })
    vim.api.nvim_create_autocmd("BufWinEnter", {
        group = group,
        buffer = bufnr,
        callback = function(args)
            local win = vim.api.nvim_get_current_win()
            local key = tostring(args.buf)
            if (vim.w[win].hledger_sections_folded or {})[key] then
                return
            end
            local filetype = vim.bo[args.buf].filetype
            vim.schedule(function()
                -- The buffer may be gone or its filetype changed meanwhile
                if not vim.api.nvim_buf_is_valid(args.buf) or vim.bo[args.buf].filetype ~= filetype then
                    return
                end
                M.close_sections(win, args.buf, function()
                    local folded = vim.w[win].hledger_sections_folded or {}
                    folded[key] = true
                    vim.w[win].hledger_sections_folded = folded
                end)
            end)
        end,
    })
end

--- Sets up folding for a journal or rules buffer in the current window, from
--- the filetype plugins: the fold expression, which takes effect with
--- 'foldmethod' set to "expr" (as Neovim's own Lua filetype plugin does), and
--- |g:hledger| `fold_sections_on_open`.
---@param bufnr integer
function M.attach(bufnr)
    vim.wo[0][0].foldexpr = "v:lua.require'hledger'.foldexpr()"
    local config, err = require("hledger.config").get()
    if err then
        vim.notify_once("hledger: " .. err, vim.log.levels.WARN)
    end
    if config.fold_sections_on_open then
        M.fold_sections_on_open(bufnr)
    end
end

--- For 'b:undo_ftplugin'
---@param bufnr integer
function M.undo(bufnr)
    pcall(vim.api.nvim_clear_autocmds, { group = GROUP, buffer = bufnr })
end

return M
