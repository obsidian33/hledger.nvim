# List recipes
default:
    @just --list

# Fetch mini.test and build the tree-sitter-hledger parsers into deps/
deps:
    scripts/fetch-deps.sh

# Run all tests, or one file: just test tests/test_editing.lua
test file="": deps
    nvim --headless --noplugin -u scripts/minimal_init.lua \
        -c "lua MiniTest.run{{ if file == '' { '()' } else { '_file(\"' + file + '\")' } }}"
