# HUD icons

Transparent 512 x 512 icons that replace the coin, strength, speed, launch, shop and
invite emoji everywhere in game, plus the black hole (the Next Black Hole product art on
its own, rendered from `tools/product-images/icons.html#BlackHoleIcon`). Drawn as SVG in `tools/hud-icons/icons.html`, rendered by
`tools/hud-icons/render.sh` (headless Chrome), uploaded to the owner account. Their ids are
in `src/ReplicatedStorage/Shared/ProductImages.luau` (HUD icons) and, for the loading bar
rocket, copied into `src/ReplicatedFirst/LoadingScreen.client.luau`. Re-uploading an image
means a new id in both places.

In game: `UI/Icon` (`Icon.new` for icon slots, `Icon.attach` for a picture beside text),
`InlineIconController` for server-built text (tag "InlineIcon" + Image attribute), and the
sign badge's Image attribute (`SignService`). The emoji stay as fallbacks if an image
can't load.
