import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/widgets/frosted_glass.dart';
import 'package:tomsllama/core/theme/app_theme.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';

void main() {
  testWidgets('FrostedGlass renders child and applies BackdropFilter with ClipRRect', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: claudeTheme,
        home: const Scaffold(
          body: FrostedGlass(
            width: 200,
            height: 100,
            borderRadius: BorderRadius.all(Radius.circular(18.0)),
            child: Text('Frosted Content'),
          ),
        ),
      ),
    );

    // Verify child is present
    expect(find.text('Frosted Content'), findsOneWidget);

    // Verify ClipRRect with correct radius
    final clipFinder = find.byType(ClipRRect);
    expect(clipFinder, findsOneWidget);
    final clipWidget = tester.widget<ClipRRect>(clipFinder);
    expect(clipWidget.borderRadius, const BorderRadius.all(Radius.circular(18.0)));

    // Verify BackdropFilter is present
    final filterFinder = find.byType(BackdropFilter);
    expect(filterFinder, findsOneWidget);
  });
}
