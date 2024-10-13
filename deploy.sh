#!/bin/bash

VAULT_DIR="/Users/seongha.moon/Library/Mobile Documents/com~apple~CloudDocs/Documents/Blog-Vault/"
ignore=(
    .DS_Store
    .obsidian
    _templates
)

rsync_exclude=""
for item in "${ignore[@]}"; do
    rsync_exclude+="--exclude=$item "
done

rsync -av --delete "$rsync_exclude" "$VAULT_DIR" ./content