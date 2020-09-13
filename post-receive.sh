#!/bin/bash

echo "Current working directory"
pwd

echo "Create target hooks directory"
# 目标仓库的相对路径
readonly TARGET_HOOKS="../../../e6/29/e629fa6598d732768f7c726b4b621285f9c3b85303900aa912017db7617d8bdb.git/custom_hooks"
mkdir -p "${TARGET_HOOKS}"

function update_file() {
    echo "update_file" "$1" "$2"
    git show HEAD:"$1" > "$2"
    chmod +x "$2"
}

echo "Update all hooks in target hooks directory"
update_file "custom_hooks/update.rb" "${TARGET_HOOKS}/update"
update_file "custom_hooks/git-author.txt" "${TARGET_HOOKS}/git-author.txt"
update_file "post-receive.sh" "custom_hooks/post-receive"
