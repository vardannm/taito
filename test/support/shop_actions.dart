import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reviews the new purchase sheet, confirms, and returns to the catalog.
Future<void> completeShopPurchase(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final confirm = find.byKey(const ValueKey('confirm-shop-purchase'));
  await tester.tap(confirm);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const ValueKey('shop-purchase-success')), findsOneWidget);
  await tester.tap(confirm);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
