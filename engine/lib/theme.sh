#!/usr/bin/env bash
load_theme() {
    source "${SQ_THEME_DIR}/theme.conf"
}

render_template() {
    envsubst < "$1"
}
