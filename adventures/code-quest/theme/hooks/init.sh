#!/usr/bin/env bash
: "${QE_PROJECT_DIR:=$HOME/project}"

if [[ ! -f "$QE_PROJECT_DIR/package.json" ]]; then
    cp -R "$QE_THEME_DIR/project/." "$QE_PROJECT_DIR/"
fi

if [[ ! -d "$QE_PROJECT_DIR/node_modules" ]]; then
    cd "$QE_PROJECT_DIR"
    npm ci --silent 2>/dev/null || npm install --silent
fi

cp "$QE_THEME_DIR/reference/vue-reference.txt" "$QE_PROJECT_DIR/vue-reference.txt" 2>/dev/null || true
