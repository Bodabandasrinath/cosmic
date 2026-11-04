// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic/app/theme.dart';
import 'package:cosmic/widgets/cosmic_button.dart';

void main() {
  testWidgets('CosmicButton renders and responds to tap', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: CosmicTheme.darkTheme,
        home: Scaffold(
          body: CosmicButton(
            text: 'Launch Cosmic',
            onPressed: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Launch Cosmic'), findsOneWidget);
    await tester.tap(find.text('Launch Cosmic'));
    expect(tapped, true);
  });
}
