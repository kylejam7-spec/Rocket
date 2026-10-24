#!/usr/bin/env bash
# Renders every icon in icons.html to assets/product-images/<Key>.png (512 x 512) with
# headless Chrome. Usage: tools/product-images/render.sh [Key ...]  (no keys = all)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/../../assets/product-images"
mkdir -p "$out"
chrome="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
page="file:///$(cygpath -m "$here/icons.html" 2>/dev/null || echo "$here/icons.html")"
keys=("$@")
if [ ${#keys[@]} -eq 0 ]; then
  keys=(DoubleCoins FastHatch MultiHatch PetSlot1 PetSlot2 SuitGold SuitCommander SuitGalaxy
    Gym1 Gym2 Gym3 Gym4 Gym5 Gym6 Gym7 GymSpaceX BulkPickup BulkPlace PlacementRange
    ServerTraining Fill2000 Fill4000 Fill7000 Fill11000 Fill27500 ExtraStay
    NextMoon NextMars NextEuropa NextSaturn NextBlackHole UfoRare UfoEpic UfoLegendary)
fi
for key in "${keys[@]}"; do
  target="$(cygpath -w "$out/$key.png" 2>/dev/null || echo "$out/$key.png")"
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --window-size=512,512 --virtual-time-budget=4000 --screenshot="$target" "$page#$key" >/dev/null 2>&1
  echo "$key"
done
