import 'support/controlled_shop_storage.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/shop_catalog.dart';
import 'package:balance_arcade/survival_upgrades.dart';

void main() {
  late ControlledShopStorage storage;
  setUp(() {
    storage = ControlledShopStorage();
    SharedPreferencesAsyncPlatform.instance = storage;
  });
  const coral = ShopProduct.ball(BallCosmetic.coral);
  const copper = ShopProduct.platform(PlatformStyle.copper);
  const magnet = ShopProduct.upgrade(SurvivalUpgrade.magnet);

  test(
    'coin purchases, equipping and upgrades are durable and charge once',
    () async {
      final p = PlayerProfile()..wallet = 290;
      expect(
        await p.purchaseShopProduct(coral, quotedPrice: 60, quotedLevel: 0),
        ShopTransactionResult.success,
      );
      expect(
        await p.purchaseShopProduct(copper, quotedPrice: 80, quotedLevel: 0),
        ShopTransactionResult.success,
      );
      expect(
        await p.purchaseShopProduct(magnet, quotedPrice: 150, quotedLevel: 0),
        ShopTransactionResult.success,
      );
      expect(p.wallet, 0);
      expect(
        await p.purchaseShopProduct(coral, quotedPrice: 0, quotedLevel: 0),
        ShopTransactionResult.success,
      );
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.wallet, 0);
      expect(restored.selectedBall, BallCosmetic.coral);
      expect(restored.selectedPlatform, PlatformStyle.copper);
      expect(restored.upgradeLevel(SurvivalUpgrade.magnet), 1);
    },
  );

  test(
    'insufficient, outdated and maximum-level requests cannot spend coins',
    () async {
      final p = PlayerProfile()..wallet = 59;
      expect(
        await p.purchaseShopProduct(coral, quotedPrice: 60, quotedLevel: 0),
        ShopTransactionResult.insufficientCoins,
      );
      p.wallet = 1000;
      expect(
        await p.purchaseShopProduct(coral, quotedPrice: 59, quotedLevel: 0),
        ShopTransactionResult.changed,
      );
      p.survivalUpgrades[SurvivalUpgrade.magnet] = 2;
      expect(
        await p.purchaseShopProduct(magnet, quotedPrice: 150, quotedLevel: 0),
        ShopTransactionResult.changed,
      );
      p.survivalUpgrades[SurvivalUpgrade.magnet] = 5;
      expect(
        await p.purchaseShopProduct(magnet, quotedPrice: 900, quotedLevel: 5),
        ShopTransactionResult.changed,
      );
      expect(p.wallet, 1000);
      expect(p.ownedBalls.contains(BallCosmetic.coral), isFalse);
    },
  );

  test(
    'failed storage preserves wallet, gear and upgrades, and permits retry',
    () async {
      final p = PlayerProfile()..wallet = 1000;
      storage.fail = true;
      for (final (item, price) in [(coral, 60), (copper, 80), (magnet, 150)]) {
        expect(
          await p.purchaseShopProduct(item, quotedPrice: price, quotedLevel: 0),
          ShopTransactionResult.storageUnavailable,
        );
      }
      expect(p.wallet, 1000);
      expect(p.selectedBall, BallCosmetic.steel);
      expect(p.selectedPlatform, PlatformStyle.classic);
      expect(p.upgradeLevel(SurvivalUpgrade.magnet), 0);
      storage.fail = false;
      expect(
        await p.purchaseShopProduct(coral, quotedPrice: 60, quotedLevel: 0),
        ShopTransactionResult.success,
      );
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.wallet, 940);
      expect(restored.selectedBall, BallCosmetic.coral);
    },
  );

  test(
    'pending transactions block duplicates and queued rewards retain their value',
    () async {
      final p = PlayerProfile()..wallet = 60;
      storage.gate = Completer<void>();
      final purchase = p.purchaseShopProduct(
        coral,
        quotedPrice: 60,
        quotedLevel: 0,
      );
      await Future<void>.delayed(Duration.zero);
      expect(p.wallet, 60);
      expect(p.ownedBalls.contains(BallCosmetic.coral), isFalse);
      expect(
        await p.purchaseShopProduct(coral, quotedPrice: 60, quotedLevel: 0),
        ShopTransactionResult.busy,
      );
      p.wallet += 25;
      final save = p.saveEconomy();
      storage.gate!.complete();
      expect(await purchase, ShopTransactionResult.success);
      await save;
      expect(p.wallet, 25);
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.wallet, 25);
      expect(restored.selectedBall, BallCosmetic.coral);
    },
  );

  test('pending shop transactions also block legacy wallet spends', () async {
    final p = PlayerProfile()..wallet = 300;
    storage.gate = Completer<void>();
    final purchase = p.purchaseShopProduct(
      coral,
      quotedPrice: 60,
      quotedLevel: 0,
    );
    await Future<void>.delayed(Duration.zero);
    expect(p.selectBall(BallCosmetic.circuit), isFalse);
    expect(p.selectPlatform(PlatformStyle.copper), isFalse);
    expect(p.buySurvivalUpgrade(SurvivalUpgrade.magnet), isFalse);
    expect(p.wallet, 300);
    storage.gate!.complete();
    expect(await purchase, ShopTransactionResult.success);
    expect(p.wallet, 240);
  });

  test(
    'unlimited test economy remains separate and never debits its wallet',
    () async {
      final p = PlayerProfile(unlimitedCoins: true);
      expect(
        await p.purchaseShopProduct(coral, quotedPrice: 60, quotedLevel: 0),
        ShopTransactionResult.success,
      );
      expect(p.wallet, 0);
      final normal = PlayerProfile();
      await normal.load();
      expect(normal.ownedBalls.contains(BallCosmetic.coral), isFalse);
    },
  );
}
