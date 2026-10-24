-- Runtime for the tests: this plugin, mini.test and the parsers in deps/
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. "/deps/mini.test")
vim.opt.runtimepath:prepend(root .. "/deps") -- deps/parser/*.so

-- The process running the tests (not the child Neovims they drive)
if #vim.api.nvim_list_uis() == 0 then
    require("mini.test").setup()
end
