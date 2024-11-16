#!/bin/bash

# ./content 하위 폴더 목록을 가져와서 첫 번째 선택
PARENT_DIR=$(find ./content -mindepth 1 -maxdepth 1 -type d | gum choose)
TARGET_DIR=$(find $PARENT_DIR -mindepth 1 -maxdepth 1 -type d | gum choose)
POST_NAME=$(gum input --placeholder "Post Name")

# PARENT_DIR 이름에서 경로를 제거하고 디렉토리 이름만 추출하여 TAG에 할당
TAG=$(basename "$TARGET_DIR")

for FILE in "$POST_NAME.md" "$POST_NAME.en.md"; do
    cat <<EOF > "$TARGET_DIR/$FILE"
---
title: $POST_NAME
type: blog
date: $(date +%Y-%m-%d)
tags: 
  - $TAG
summary: ""
---
EOF
done