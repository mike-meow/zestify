// Health AI App widget tests
//
// These tests verify that our app's widgets render correctly and contain
// the expected components.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_ai/main.dart';
import 'package:health_ai/screens/home_screen.dart';
import 'package:health_ai/widgets/health_orb.dart';
import 'package:health_ai/widgets/bubble_card.dart';
import 'package:health_ai/widgets/chat_box.dart';

void main() {
  testWidgets('App should render without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app renders without errors
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('HomeScreen should contain key components', (
    WidgetTester tester,
  ) async {
    // Build the HomeScreen widget
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Verify that the key components are present
    expect(find.byType(HealthOrb), findsOneWidget);
    expect(find.byType(BubbleCard), findsAtLeastNWidgets(1));
    expect(find.byType(ChatBox), findsOneWidget);

    // Verify text elements
    expect(find.text('Your Health Score'), findsOneWidget);
    expect(find.text('Your Wellness Journey'), findsOneWidget);
  });

  testWidgets('HealthOrb should display score correctly', (
    WidgetTester tester,
  ) async {
    const testScore = 85;

    // Build the HealthOrb widget
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HealthOrb(healthScore: testScore)),
      ),
    );

    // Verify that the score is displayed
    expect(find.text('$testScore'), findsOneWidget);
  });
}
