import 'package:balance_arcade/rewarded_revive_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Use the SDK's native channel codec to test the real adapter callbacks.
import 'package:google_mobile_ads/src/ad_instance_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GoogleTestReviveAds ads;
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> event(String name, [Map<String, Object>? values]) async {
    final load = calls.lastWhere((c) => c.method == 'loadRewardedAd');
    final data = instanceManager.channel.codec.encodeMethodCall(
      MethodCall('onAdEvent', {
        'adId': load.arguments['adId'],
        'eventName': name,
        ...?values,
      }),
    );
    await messenger.handlePlatformMessage(
      instanceManager.channel.name,
      data,
      (_) {},
    );
  }

  setUp(() {
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    calls.clear();
    ads = GoogleTestReviveAds();
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      calls.add(call);
      if (call.method == 'MobileAds#initialize') {
        return InitializationStatus(<String, AdapterStatus>{});
      }
      return null;
    });
  });

  tearDown(() {
    ads.dispose();
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  void adTest(
    String description,
    WidgetTesterCallback callback, {
    TargetPlatform platform = TargetPlatform.android,
  }) {
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    adTest('$platform uses test ads and waits for both reward and dismissal', (
      tester,
    ) async {
      ReviveAdResult? result;
      ads.show().then((value) => result = value);
      await tester.pump();
      final load = calls.singleWhere((c) => c.method == 'loadRewardedAd');
      expect(
        load.arguments['adUnitId'],
        platform == TargetPlatform.android
            ? GoogleTestReviveAds.androidUnit
            : GoogleTestReviveAds.iosUnit,
      );
      await event('onAdLoaded');
      await tester.pump();
      expect(calls.where((c) => c.method == 'showAdWithoutView'), hasLength(1));
      expect(await ads.show(), ReviveAdResult.unavailable);
      await event('onRewardedAdUserEarnedReward', {
        'rewardItem': RewardItem(1, 'heart'),
      });
      await tester.pump();
      expect(result, isNull);
      await event(
        platform == TargetPlatform.android
            ? 'onAdDismissedFullScreenContent'
            : 'adDidDismissFullScreenContent',
      );
      await tester.pump();
      expect(result, ReviveAdResult.earned);
      expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
    }, platform: platform);
  }

  adTest('dismissal without reward earns nothing', (tester) async {
    final result = ads.show();
    await tester.pump();
    await event('onAdLoaded');
    await tester.pump();
    await event('onAdDismissedFullScreenContent');
    expect(await result, ReviveAdResult.dismissed);
  });

  adTest('failed loading allows a fresh attempt', (tester) async {
    final first = ads.show();
    await tester.pump();
    await event('onAdFailedToLoad', {
      'loadAdError': LoadAdError(3, 'test', 'no fill', null),
    });
    expect(await first, ReviveAdResult.unavailable);
    final second = ads.show();
    await tester.pump();
    expect(calls.where((c) => c.method == 'loadRewardedAd'), hasLength(2));
    await event('onAdLoaded');
    await tester.pump();
    await event('onAdDismissedFullScreenContent');
    expect(await second, ReviveAdResult.dismissed);
  });

  adTest('failed presentation disposes the ad without a reward', (
    tester,
  ) async {
    final result = ads.show();
    await tester.pump();
    await event('onAdLoaded');
    await tester.pump();
    await event('onFailedToShowFullScreenContent', {
      'error': AdError(1, 'test', 'failed'),
    });
    expect(await result, ReviveAdResult.unavailable);
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
  });

  adTest('a timed-out load cannot open a late ad', (tester) async {
    final result = ads.show();
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    expect(await result, ReviveAdResult.unavailable);
    await event('onAdLoaded');
    await tester.pump();
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
  });

  adTest('disposing during loading prevents presentation', (tester) async {
    final result = ads.show();
    await tester.pump();
    ads.dispose();
    await event('onAdLoaded');
    await tester.pump(const Duration(seconds: 16));
    expect(await result, ReviveAdResult.unavailable);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
  });

  adTest('disposal during a displayed ad rejects late rewards', (tester) async {
    final result = ads.show();
    await tester.pump();
    await event('onAdLoaded');
    await tester.pump();
    ads.dispose();
    expect(await result, ReviveAdResult.unavailable);
    await event('onRewardedAdUserEarnedReward', {
      'rewardItem': RewardItem(1, 'heart'),
    });
    await event('onAdDismissedFullScreenContent');
    expect(await ads.show(), ReviveAdResult.unavailable);
  });

  test('desktop does not initialize the ad SDK', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(ads.supported, isFalse);
    expect(await ads.show(), ReviveAdResult.unavailable);
    expect(calls, isEmpty);
  });
}
