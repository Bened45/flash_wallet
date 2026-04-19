import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_wallet/main.dart';

void main() {
  testWidgets('Flash app smoke test', (WidgetTester tester) async {
    // Build our app wrapped in ProviderScope
    await tester.pumpWidget(
      ProviderScope(
        child: FlashApp(),
      ),
    );

    // Verify that the app builds without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
