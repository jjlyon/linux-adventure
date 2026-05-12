#!/usr/bin/env bash
: "${QE_PROJECT_DIR:=$HOME/project}"

find "$QE_PROJECT_DIR/src/components" -name "*.vue" -delete 2>/dev/null || true
rm -rf "$QE_PROJECT_DIR/src/router" 2>/dev/null || true
rm -rf "$QE_PROJECT_DIR/src/views" 2>/dev/null || true

cp "$QE_THEME_DIR/project/src/App.vue" "$QE_PROJECT_DIR/src/App.vue"
cp "$QE_THEME_DIR/project/src/main.js" "$QE_PROJECT_DIR/src/main.js"
cp "$QE_THEME_DIR/project/src/style.css" "$QE_PROJECT_DIR/src/style.css"

touch "$QE_PROJECT_DIR/src/components/.gitkeep"

cp "$QE_THEME_DIR/reference/vue-reference.txt" "$QE_PROJECT_DIR/vue-reference.txt" 2>/dev/null || true
