import 'package:balance_arcade/ad_consent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_channel.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final channel = MethodChannel(
    'rollrise/ump-test',
    StandardMethodCodec(UserMessagingCodec()),
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  bool eligible = false, updateFails = false, optionsRequired = false;
  late AdConsent consent;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    eligible = false;
    updateFails = false;
    optionsRequired = false;
    consent = AdConsent();
    UserMessagingChannel.instance = UserMessagingChannel(channel);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method.endsWith('#requestConsentInfoUpdate') && updateFails) {
        throw PlatformException(code: '1', message: 'offline');
      }
      if (call.method.endsWith('#canRequestAds')) return eligible;
      if (call.method.endsWith('#getPrivacyOptionsRequirementStatus'))
        return optionsRequired ? 1 : 0;
      if (call.method.endsWith('#showPrivacyOptionsForm')) eligible = false;
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  test('updates once per launch and checks UMP before each ad', () async {
    optionsRequired = true;
    expect(await consent.canRequestAds(), false);
    eligible = true;
    expect(await consent.canRequestAds(), true);
    expect(consent.privacyOptionsRequired, true);
    expect(
      calls.where((m) => m.endsWith('#requestConsentInfoUpdate')),
      hasLength(1),
    );
    expect(
      calls.indexOf('UserMessagingPlatform#loadAndShowConsentFormIfRequired'),
      lessThan(calls.indexOf('ConsentInformation#canRequestAds')),
    );
  });
  test(
    'offline update respects prior SDK eligibility without a new form',
    () async {
      updateFails = true;
      eligible = true;
      expect(await consent.canRequestAds(), true);
      expect(
        calls,
        isNot(
          contains('UserMessagingPlatform#loadAndShowConsentFormIfRequired'),
        ),
      );
    },
  );
  test('offline first launch cannot request ads', () async {
    updateFails = true;
    expect(await consent.canRequestAds(), false);
  });
  test('privacy changes are rechecked before the next ad', () async {
    eligible = true;
    optionsRequired = true;
    expect(await consent.canRequestAds(), true);
    expect(await consent.showPrivacyOptions(), null);
    expect(await consent.canRequestAds(), false);
  });
  test('desktop never calls UMP or enables ads', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(await consent.canRequestAds(), false);
    expect(calls, isEmpty);
  });
}
