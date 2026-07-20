#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ANSI colors
c_reset=$'\033[0m'
c_blue=$'\033[0;34m'
c_green=$'\033[0;32m'

# Stop Greekboard if running
print "${c_blue}Killing the running Greekboard application...${c_reset}"
killall -q "GreekKeyboardViewer" || true
print "${c_green}Done.${c_reset}\n"

# Build via build_app.sh
"$(dirname "$0")/build_app.sh"

# Launch output/Greekboard.app
print "${c_blue}Running Greekboard...${c_reset}"
open "$ROOT_DIR/output/Greekboard.app"
print "${c_green}Done.${c_reset}\n"
