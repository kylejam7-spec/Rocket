# Product images

512 x 512 PNGs for the Creator Dashboard, one per Game Pass and Developer Product in
`Config.Shop` and `Config.RobuxUpgrades`. Drawn as SVG in `tools/product-images/icons.html`
and rendered by `tools/product-images/render.sh` (headless Chrome; pass keys to redo some).
Game Pass images are shown cropped to a circle, so the art and labels stay inside it.

In game, `src/ReplicatedStorage/Shared/ProductImages.luau` holds the uploaded ids (owner
account, user 1502038929) and `UI/Icon` shows them on shop cards, buttons and rows, with the
emoji as fallback. The suit images are dashboard-only: suits sell through stand prompts.
Re-uploading an image means a new id there.

The planet art uses the CC0 Planet Texture Pack already listed in `assets/LICENSES.md`;
everything else is original vector art. The font is Fredoka One (SIL OFL).

## Game Passes (`Config.Shop.passes`)

| Image | Pass |
| --- | --- |
| `DoubleCoins.png` | 2x Coins |
| `FastHatch.png` | Fast Hatch |
| `MultiHatch.png` | Triple Hatch |
| `PetSlot1.png` | +1 Pet Slot |
| `PetSlot2.png` | +2 Pet Slots |
| `SuitGold.png` | Gold Astronaut Skin |
| `SuitCommander.png` | Commander Astronaut Skin |
| `SuitGalaxy.png` | Galaxy Astronaut Skin |
| `Gym1.png` | Gym tier 1 (2x) |
| `Gym2.png` | Gym tier 2 (5x) |
| `Gym3.png` | Gym tier 3 (10x) |
| `Gym4.png` | Gym tier 4 (25x) |
| `Gym5.png` | Gym tier 5 (50x) |
| `Gym6.png` | Gym tier 6 (75x) |
| `Gym7.png` | Gym tier 7 (100x) |

## Upgrade level passes (`Config.RobuxUpgrades`)

Each track has 10 level passes. All 10 use the same generic "+1" image.

| Image | Passes |
| --- | --- |
| `BulkPickup.png` | Bulk Pickup, levels 1-10 |
| `BulkPlace.png` | Bulk Place, levels 1-10 |
| `PlacementRange.png` | Placement Range, levels 1-10 |

## Developer Products (`Config.Shop.products`)

| Image | Product |
| --- | --- |
| `ServerTraining.png` | 2x server training, 10 min |
| `Fill2000.png` | +2,000 rocket parts |
| `Fill4000.png` | +4,000 rocket parts |
| `Fill7000.png` | +7,000 rocket parts |
| `Fill11000.png` | +11,000 rocket parts |
| `Fill27500.png` | +27,500 rocket parts |
| `ExtraStay.png` | +60 s at the destination |
| `NextMoon.png` | Next mission: Moon |
| `NextMars.png` | Next mission: Mars |
| `NextEuropa.png` | Next mission: Europa |
| `NextSaturn.png` | Next mission: Saturn |
| `NextBlackHole.png` | Next mission: Black Hole |
| `UfoRare.png` | Rare UFO |
| `UfoEpic.png` | Epic UFO |
| `UfoLegendary.png` | Legendary UFO |
