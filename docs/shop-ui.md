# Gear Shop

The shop uses Rollrise's brass, deep teal, mint, typography, coin painter and actual equipment/world painters. The catalog contains all 23 balls, 16 platforms and three permanent Infinite upgrades. Gameplay definitions remain the source of prices, bonuses, descriptions and upgrade limits.

## Research and design decisions

Research reviewed on 29 October 2026:

- [Brawl Stars shop changes](https://supercell.com/en/games/brawlstars/blog/news/changes-to-bling-shop-and-cosmetics/): a large catalog creates choice overload. Rollrise features the next unowned world and provides search, ownership/affordability filters and sorting. Its full catalog stays available because Rollrise has no rotating-offer service.
- [Brawl Stars previews](https://support.supercell.com/brawl-stars/en/articles/skins-7.html): inspect a cosmetic before acquiring it. Rollrise previews the actual ball, world or platform, with its full description and Infinite benefits.
- [Clash Royale shop](https://support.clashroyale.com/hc/en-us/articles/49484889956251-Shop-Offers): distinct product groups and clear currency requirements. Rollrise keeps persistent category tabs, a wallet, exact prices and an actionable coin shortfall.
- [Pokémon GO's official store](https://store.pokemongo.com/en): artwork, named contents and visible prices make offers comparable. Rollrise explicitly identifies the world included with a ball, premium equipment and permanent upgrades.

The UI avoids invented discounts, timers, scarcity, bundles or reward claims. Small transitions, equipped borders, actual animated previews and a saved-purchase receipt provide feedback. Reduced motion stops previews and removes receipt animation; covered routes and backgrounded apps stop their preview controllers.

## Purchase flow

1. Inspect an item using its artwork or price button. Owned equipment can be equipped without spending coins.
2. Review its full description, world, benefits, loadout comparison, price and resulting wallet balance.
3. Confirm the purchase. Navigation and the confirmation button are disabled while the local save is pending.
4. `PlayerProfile.purchaseShopProduct` revalidates the quote, ownership, upgrade level, cap and wallet inside the economy write queue. It persists a draft before publishing the new ownership, equipment or balance.
5. On success, show a receipt and optional haptic. On failure, keep the wallet and equipment unchanged, explain the failure and allow retry. Stale quotes require another review; duplicate in-flight requests are rejected.

Economy writes read current state when they execute, so a queued save cannot overwrite a preceding purchase with an older wallet snapshot. Rewards earned during a pending transaction retain their separately queued save. Stable saved enum names and the separate unlimited test economy are preserved.

## Coins and missing billing

There is **no App Store / Google Play billing or verified entitlement backend in this project**. Placeholder paid packs, USD prices and the nonfunctional Restore button have been removed. The wallet and insufficient-balance links open an earning screen with real daily-prize and achievement claim screens, plus accurate descriptions of gameplay rewards. No fake checkout or purchase result is offered.

To add paid packs, first implement store product discovery/localized prices, purchase and pending/cancelled/error handling, receipt verification, idempotent coin delivery and transaction completion. Consumable coin packs should follow the stores' actual recovery behavior rather than promising a generic restoration of spent currency. Current ownership and wallet data are device-local, with the existing manual backup system; this work does not add cloud accounts.

## Structure and extending the shop

- `shop_catalog.dart`: typed catalog entries and transaction results.
- `shop_product_state.dart`: current ownership, price, level and comparison values.
- `shop_artwork.dart`: shared game artwork presentation.
- `shop_product_card.dart`: catalog cards and featured world.
- `shop_product_sheet.dart`: preview, quote, confirmation, progress, error and receipt.
- `ball_shop.dart`: browsing, category state, responsive rows, tutorial and swipe navigation.
- `coin_store.dart`: wallet and existing coin-earning paths.
- `profile.dart`: durable transactions and existing economy persistence.

Add balls/platforms to their gameplay enums to populate the catalog automatically. New upgrade types require their gameplay definition and icon/art mapping. New currencies or product types should extend the domain model and transaction validation together; prices should never be invented in the UI.

## Validation

Verified on 29 October 2026: the release web build succeeds; source analysis is clean; all 24 focused shop/world-integration tests and all 20 visual exports pass. The full suite reports **807 passing tests and five existing failures**. Those same failures reproduce in an untouched export of commit `5d4d528`:

- `classic_progression_test.dart`: warning/motion openings; mechanic introductions.
- `classic_star_test.dart`: reachable collectible on level 25.
- `mastery_test.dart`: trap-adjacent pickup candidates on level 23.
- `spiders_test.dart`: target scatter after the introductory level.

These level-design failures are outside this shop change. Baseline and final run logs are retained in ignored `artifacts/shop-baseline-tests.log`, `artifacts/shop-baseline-spiders.log`, and `artifacts/shop-final-regression.log`.

Run `./scripts/flutter.ps1 test --no-pub` for regression coverage. Shop tests exercise successful and failed saves, pending/double requests, stale quotes, insufficient currency, upgrade caps, persistence, reward claims, owned gear, filtering, sorting, category scroll restoration, onboarding and reduced-motion layouts.

`./scripts/flutter.ps1 test --no-pub tool/render_shop.dart` renders catalog, details, success and upgrades at 390×844, 320×568 with 1.8× text, 820×1180, 1440×900 and 844×390. PNGs are written to ignored `artifacts/shop/` for visual inspection. UI tests additionally exercise 2× text and a 540×720 viewport. Analyze source with `./scripts/flutter.ps1 analyze --no-pub lib test tool`; repository-wide analysis also sees unrelated generated level backups under ignored `artifacts/`.
