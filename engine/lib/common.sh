#!/usr/bin/env bash
set -euo pipefail
SQ_BOLD='\033[1m'; SQ_RESET='\033[0m'
info(){ printf '%b\n' "$*"; }
section(){ printf '\n%b%s%b\n' "$SQ_BOLD" "$1" "$SQ_RESET"; }
