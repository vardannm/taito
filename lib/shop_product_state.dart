import 'profile.dart';
import 'shop_catalog.dart';
import 'survival_upgrades.dart';

extension ShopProductState on ShopProduct {
  bool ownedBy(PlayerProfile p) => ball != null
      ? p.ownedBalls.contains(ball)
      : platform != null && p.ownedPlatforms.contains(platform);
  bool equippedBy(PlayerProfile p) => ball != null
      ? p.selectedBall == ball
      : platform != null && p.selectedPlatform == platform;
  int levelFor(PlayerProfile p) =>
      upgrade == null ? 0 : p.upgradeLevel(upgrade!);
  bool maxedFor(PlayerProfile p) =>
      upgrade != null && levelFor(p) >= upgrade!.maxLevel;
  int priceFor(PlayerProfile p) =>
      ownedBy(p) || maxedFor(p) ? 0 : price(levelFor(p));
  double multiplierFor(PlayerProfile p) =>
      1 +
      bonus +
      (ball != null
          ? p.selectedPlatform.scoreBonus
          : p.selectedBall.scoreBonus);
}
