#!/bin/bash

# ./content 하위 폴더 목록을 가져와서 선택
PARENT_DIR=$(find ./content -mindepth 1 -maxdepth 1 -type d | gum choose)

DIR_NAME=$(gum input --placeholder "Directory Name")
TARGET_DIR="$PARENT_DIR/$DIR_NAME"
TITLE=$(echo "$DIR_NAME" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')

if [ -d "$TARGET_DIR" ]; then
  echo "Error: Directory '$TARGET_DIR' already exists."
else
  mkdir -p "$TARGET_DIR"
  echo "Directory '$TARGET_DIR' created successfully."

  for FILE in "_index.md" "_index.en.md"; do
    cat <<EOF > "$TARGET_DIR/$FILE"
---
title: $TITLE
type: blog
comments: false
sidebar:
  open: open
---
EOF
  done

  echo "_index.md and _index.en.md files created and initialized in '$TARGET_DIR'."
fi