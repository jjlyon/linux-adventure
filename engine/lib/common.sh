#!/usr/bin/env bash
QE_BOLD='\033[1m'
QE_GREEN='\033[0;32m'
QE_CYAN='\033[0;36m'
QE_YELLOW='\033[0;33m'
QE_RESET='\033[0m'

if [[ -n "${QE_THEME_DIR:-}" && -f "${QE_THEME_DIR}/theme.conf" ]]; then
    source "${QE_THEME_DIR}/theme.conf"
fi

qe_banner() {
    printf '\n'
    printf '  %b✦ ═══════════════════════════════════════ ✦%b\n' "$QE_YELLOW" "$QE_RESET"
    printf '\n'
}

qe_banner_end() {
    printf '\n'
    printf '  %b✦ ═══════════════════════════════════════ ✦%b\n' "$QE_YELLOW" "$QE_RESET"
    printf '\n'
}
