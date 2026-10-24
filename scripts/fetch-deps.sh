#!/usr/bin/env bash
# Fetches what the tests need into deps/:
#   deps/mini.test        the test framework
#   deps/parser/*.so      the tree-sitter-hledger parsers, built with the tree-sitter CLI
set -euo pipefail

MINI_TEST_VERSION=v0.18.0
TREE_SITTER_HLEDGER_REVISION=702ec4c7eb3c8ea0accaa7fa8e24ade886db8a52

root=$(cd "$(dirname "$0")/.." && pwd)
deps="$root/deps"
mkdir -p "$deps/parser"

if [ ! -d "$deps/mini.test" ]; then
    git clone --quiet --depth 1 --branch "$MINI_TEST_VERSION" \
        https://github.com/nvim-mini/mini.test "$deps/mini.test"
fi

stamp="$deps/parser/.revision"
if [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$TREE_SITTER_HLEDGER_REVISION" ]; then
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL "https://codeload.github.com/obsidian33/tree-sitter-hledger/tar.gz/$TREE_SITTER_HLEDGER_REVISION" |
        tar -xz -C "$tmp" --strip-components=1
    tree-sitter build -o "$deps/parser/hledger.so" "$tmp/journal"
    tree-sitter build -o "$deps/parser/hledger_rules.so" "$tmp/rules"
    echo "$TREE_SITTER_HLEDGER_REVISION" > "$stamp"
fi
