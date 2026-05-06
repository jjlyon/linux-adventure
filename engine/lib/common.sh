#!/usr/bin/env bash
SQ_BOLD='\033[1m'
SQ_GREEN='\033[0;32m'
SQ_CYAN='\033[0;36m'
SQ_YELLOW='\033[0;33m'
SQ_RESET='\033[0m'

sq_banner() {
    printf '
'
    printf '  %b✦ ═══════════════════════════════════════ ✦%b
' "$SQ_YELLOW" "$SQ_RESET"
    printf '
'
}

sq_banner_end() {
    printf '
'
    printf '  %b✦ ═══════════════════════════════════════ ✦%b
' "$SQ_YELLOW" "$SQ_RESET"
    printf '
'
}
