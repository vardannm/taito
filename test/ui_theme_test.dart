import 'package:balance_arcade/menu_design.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  tearDown(() => currentUiTheme = UiTheme.deepTeal);

  test('every theme has a full palette and unknown names fall back', () {
    expect(UiPalette.themes.keys, UiTheme.values);
    expect(UiTheme.named('slateSky'), UiTheme.slateSky);
    expect(UiTheme.named('gone'), UiTheme.deepTeal);
    expect(UiTheme.named(null), UiTheme.deepTeal);
    expect(
      UiPalette.themes[UiTheme.deepTeal]!.accent,
      const Color(0xFFE9C47C),
      reason: 'the original look stays available unchanged',
    );
  });

  test('the chosen theme survives a reload', () async {
    final profile = PlayerProfile()..uiTheme = UiTheme.plumDusk.name;
    await profile.save();
    final loaded = PlayerProfile();
    await loaded.load();
    expect(UiTheme.named(loaded.uiTheme), UiTheme.plumDusk);
  });

  testWidgets('picking a theme repaints even const widgets at once', (
    tester,
  ) async {
    UiTheme? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => Column(
              children: [
                const MenuSection('Theme'),
                Expanded(
                  child: SingleChildScrollView(
                    child: UiThemePicker(
                      value: currentUiTheme,
                      onChanged: (theme) {
                        picked = theme;
                        applyUiTheme(theme);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Color sectionColor() =>
        tester.widget<Text>(find.text('THEME').first).style!.color!;
    final before = sectionColor();
    await tester.tap(find.byKey(const ValueKey('ui-theme-slateSky')));
    await tester.pump();
    expect(picked, UiTheme.slateSky);
    expect(currentUiTheme, UiTheme.slateSky);
    expect(sectionColor(), isNot(before));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ui-theme-slateSky')),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
  });
}
