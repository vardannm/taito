# Premium balls and platforms

Status: Completed (2026-10-13).

User requested beautiful, stronger gear after Black Hole and explicitly chose to reserve it for future real-money purchases.

- Four new balls: Aether, Phoenix, Chronosphere, Genesis. Four matching platforms: Aether bridge, Phoenix forge, Chrono relay, Genesis arc.
- Distinct vector artwork, worlds, trails and platform inlays. Ball bonuses +4/+4.75/+5.5/+6.5; magnets 78/90/105/120. Platforms +3.5/+4/+4.5/+5. Highest combined multiplier x12.5.
- Coming soon cards; no real-money checkout or invented prices. Coin purchases (including unlimited mode) and daily gifts cannot unlock these items. Existing owned entitlements equip/save by stable names for future billing integration.
- New lock/persistence tests pass; existing magnet, world-contrast, rolling artwork, daily prize and coin-purchase checks pass. Analysis is clean. Broader checks reproduce three previously recorded baseline HUD/pacing failures; no new failure found.
- All 32 final gear/world/magnet/purchase/prize/render checks pass. Balls and platforms have disabled Coming soon actions on a 320px phone at 1.8x text size.
- Artwork inspected in artifacts/premium-gear-gallery.png, premium-gear-shop.png and premium-platform-shop.png. Release web build succeeds at build/web. No implementation work remains for this requested reserved catalog; actual store billing and product prices are future work.

Preserve unrelated existing workspace edits. Codex-wide usage-reset monitoring remains active independently of this task.
