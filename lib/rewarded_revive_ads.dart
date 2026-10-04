import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum ReviveAdResult { earned, dismissed, unavailable }

abstract interface class RewardedReviveAds {
  bool get supported;
  Future<ReviveAdResult> show();
  void dispose();
}

/// Desktop, web and ordinary widget tests never fabricate a rewarded view.
class UnavailableReviveAds implements RewardedReviveAds {
  const UnavailableReviveAds();
  @override
  bool get supported => false;
  @override
  Future<ReviveAdResult> show() async => ReviveAdResult.unavailable;
  @override
  void dispose() {}
}

/// Google sample units only. Replace both native app IDs and these units before
/// monetizing. Loading is on demand, while the game is stopped at game over.
class GoogleTestReviveAds implements RewardedReviveAds {
  static const androidUnit = 'ca-app-pub-3940256099942544/5224354917';
  static const iosUnit = 'ca-app-pub-3940256099942544/1712485313';
  bool _disposed = false, _busy = false;
  Future<void>? _initialization;
  Completer<ReviveAdResult>? _result;

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<ReviveAdResult> show() async {
    if (!supported || _disposed || _busy) return ReviveAdResult.unavailable;
    _busy = true;
    RewardedAd? loaded;
    var acceptingLoad = true;
    try {
      _initialization ??= MobileAds.instance.initialize().then((_) {});
      await _initialization!.timeout(const Duration(seconds: 15));
      if (_disposed) return ReviveAdResult.unavailable;
      final loading = Completer<RewardedAd?>();
      await RewardedAd.load(
        adUnitId: defaultTargetPlatform == TargetPlatform.android
            ? androidUnit
            : iosUnit,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (!acceptingLoad || _disposed || loading.isCompleted) {
              unawaited(ad.dispose());
            } else {
              loading.complete(ad);
            }
          },
          onAdFailedToLoad: (_) {
            if (!loading.isCompleted) loading.complete(null);
          },
        ),
      );
      loaded = await loading.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );
      acceptingLoad = false;
      if (loaded == null || _disposed) {
        if (loaded != null) unawaited(loaded.dispose());
        return ReviveAdResult.unavailable;
      }
      final result = Completer<ReviveAdResult>();
      _result = result;
      var earned = false;
      void finish(ReviveAdResult value) {
        if (!result.isCompleted) result.complete(value);
      }

      loaded.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
        onAdDismissedFullScreenContent: (ad) {
          unawaited(ad.dispose());
          finish(earned ? ReviveAdResult.earned : ReviveAdResult.dismissed);
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          unawaited(ad.dispose());
          finish(ReviveAdResult.unavailable);
        },
      );
      await loaded.show(
        onUserEarnedReward: (_, _) {
          earned = true;
        },
      );
      // Wait for dismissal as well as the reward, so gameplay never resumes
      // underneath the full-screen ad. Closing without this callback earns none.
      return await result.future;
    } catch (_) {
      if (loaded != null) unawaited(loaded.dispose());
      _initialization = null;
      return ReviveAdResult.unavailable;
    } finally {
      acceptingLoad = false;
      _busy = false;
      _result = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final result = _result;
    if (result != null && !result.isCompleted) {
      result.complete(ReviveAdResult.unavailable);
    }
    // A displayed native ad owns its dismissal; its callback disposes it.
  }
}
