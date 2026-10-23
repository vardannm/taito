import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// UMP is the authority for ad eligibility. No consent strings are cached here.
class AdConsent extends ChangeNotifier {
  Future<void>? _initialization;
  bool privacyOptionsRequired = false;
  bool _showingOptions = false;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() => _initialization ??= _gather();

  Future<void> _gather() async {
    if (!supported) return;
    final update = Completer<bool>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          if (!update.isCompleted) update.complete(true);
        },
        (_) {
          if (!update.isCompleted) update.complete(false);
        },
      );
      if (await update.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => false,
      )) {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      }
      await _refreshOptions();
    } catch (error) {
      debugPrint('Ad consent unavailable: $error');
    }
  }

  Future<void> _refreshOptions() async {
    privacyOptionsRequired =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    notifyListeners();
  }

  Future<bool> canRequestAds() async {
    if (!supported || _showingOptions) return false;
    await initialize();
    try {
      final allowed = await ConsentInformation.instance.canRequestAds();
      return allowed && !_showingOptions;
    } catch (_) {
      return false;
    }
  }

  /// Returns a user-visible error; changing choices never grants a game reward.
  Future<String?> showPrivacyOptions() async {
    if (!supported || _showingOptions) return null;
    _showingOptions = true;
    String? message;
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null)
          message = 'Privacy choices are unavailable. Please try again.';
      });
      await _refreshOptions();
    } catch (_) {
      message = 'Privacy choices are unavailable. Please try again.';
    } finally {
      _showingOptions = false;
    }
    return message;
  }
}
