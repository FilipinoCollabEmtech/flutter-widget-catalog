// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeruta/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // The loading screen holds for three seconds while the shell builds behind
    // it; run past it so no startup timer is left pending.
    await tester.pump(const Duration(seconds: 3));

    // Verify the app builds without throwing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}