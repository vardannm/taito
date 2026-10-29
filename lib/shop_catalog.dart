import 'ball_cosmetics.dart';
import 'platforms.dart';
import 'survival_upgrades.dart';

/// Catalog metadata stays independent of widgets and the player's save.
/// Prices and benefits come from the same definitions used by gameplay.
class ShopProduct {
  const ShopProduct.ball(BallCosmetic value)
    : ball = value,
      platform = null,
      upgrade = null;
  const ShopProduct.platform(PlatformStyle value)
    : platform = value,
      ball = null,
      upgrade = null;
  const ShopProduct.upgrade(SurvivalUpgrade value)
    : upgrade = value,
      ball = null,
      platform = null;

  final BallCosmetic? ball;
  final PlatformStyle? platform;
  final SurvivalUpgrade? upgrade;

  String get id => ball != null
      ? 'buy-${ball!.name}'
      : platform != null
      ? 'buy-platform-${platform!.name}'
      : 'upgrade-${upgrade!.name}';
  String get name => ball?.label ?? platform?.label ?? upgrade!.label;
  String get description =>
      ball?.description ??
      platform?.description ??
      switch (upgrade!) {
        SurvivalUpgrade.magnet =>
          'Keep the coin magnet active for longer after every pickup.',
        SurvivalUpgrade.shield =>
          'Give every shield pickup more time to protect your run.',
        SurvivalUpgrade.hearts =>
          'Start each new Infinite run with an extra chance to climb higher.',
      };
  int price(int level) =>
      ball?.cost ?? platform?.cost ?? upgrade!.costAt(level);
  double get bonus => ball?.scoreBonus ?? platform?.scoreBonus ?? 0;
  bool get premium => ball?.purchaseOnly ?? platform?.purchaseOnly ?? false;
  int get color =>
      ball?.color ??
      platform?.color ??
      switch (upgrade!) {
        SurvivalUpgrade.magnet => 0xFF82D9BE,
        SurvivalUpgrade.shield => 0xFF8ACBEE,
        SurvivalUpgrade.hearts => 0xFFED9E9A,
      };
}

final shopCatalog = List<List<ShopProduct>>.unmodifiable([
  List<ShopProduct>.unmodifiable(ballShopOrder.map(ShopProduct.ball)),
  List<ShopProduct>.unmodifiable(platformShopOrder.map(ShopProduct.platform)),
  List<ShopProduct>.unmodifiable(SurvivalUpgrade.values.map(ShopProduct.upgrade)),
]);

enum ShopTransactionResult {
  success,
  insufficientCoins,
  changed,
  storageUnavailable,
  busy,
}
