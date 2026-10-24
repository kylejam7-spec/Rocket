#!/usr/bin/env bash
# Renders the HUD icons in icons.html to assets/hud-icons/<Key>.png (512 x 512,
# transparent) with headless Chrome. Usage: tools/hud-icons/render.sh [Key ...]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/../../assets/hud-icons"
mkdir -p "$out"
chrome="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
page="file:///$(cygpath -m "$here/icons.html" 2>/dev/null || echo "$here/icons.html")"
keys=("$@")
[ ${#keys[@]} -eq 0 ] && keys=(Coin Strength Speed Launch Shop Invite)
for key in "${keys[@]}"; do
  target="$(cygpath -w "$out/$key.png" 2>/dev/null || echo "$out/$key.png")"
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --default-background-color=00000000 \
    --window-size=512,512 --virtual-time-budget=2000 --screenshot="$target" "$page#$key" >/dev/null 2>&1
  echo "$key"
done
