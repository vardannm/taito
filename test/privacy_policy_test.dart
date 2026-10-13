import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/privacy_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'start_flow_test.dart' show launch;

void main() {
  String? copiedText;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    copiedText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'privacy policy is readable from Settings offline and returns to Settings',
    (tester) async {
      await tester.runAsync(
        () => rootBundle.loadString('assets/privacy/policy.json'),
      );
      await launch(tester, ControlMode.oneFinger);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      await tester.ensureVisible(find.byKey(const ValueKey('privacy-policy')));
      await tester.tap(find.byKey(const ValueKey('privacy-policy')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(PrivacyPolicyPage), findsOneWidget);
      await tester.runAsync(() async {});
      await tester.pump();
      expect(find.text('Your game data'), findsOneWidget);
      expect(
        find.textContaining('not automatically uploaded to a GILT server'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close privacy policy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      expect(find.byType(PrivacyPolicyPage), findsNothing);
      expect(find.byKey(const ValueKey('privacy-policy')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'policy supports enlarged text on small screens and explicit link copying',
    (tester) async {
      await tester.runAsync(
        () => rootBundle.loadString('assets/privacy/policy.json'),
      );
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.6),
            ),
            child: PrivacyPolicyPage(),
          ),
        ),
      );
      await tester.runAsync(() async {});
      await tester.pump();
      expect(find.text('Your game data'), findsOneWidget);
      final copy = find.widgetWithText(TextButton, 'Copy link').first;
      await tester.ensureVisible(copy);
      await tester.pump();
      await tester.tap(copy);
      await tester.pump();
      expect(copiedText, 'https://policies.google.com/privacy');
      expect(find.text('Link copied'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
