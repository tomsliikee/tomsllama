import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/features/shell/widgets/csd_header_bar.dart';

void main() {
  testWidgets('CsdHeaderBar renders logo, title, and sidebar toggle button', (WidgetTester tester) async {
    bool toggled = false;
    bool openedSettings = false;
    bool openedQuickSwitcher = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: claudeTheme,
          home: Scaffold(
            body: CsdHeaderBar(
              onToggleSidebar: () => toggled = true,
              onOpenSettings: () => openedSettings = true,
              onOpenQuickSwitcher: () => openedQuickSwitcher = true,
              isSidebarOpen: true,
            ),
          ),
        ),
      ),
    );

    // Verify brand logo and title
    expect(find.text('tomsllama'), findsOneWidget);

    // Verify sidebar toggle button
    final toggleBtn = find.byKey(const Key('sidebar_toggle_button'));
    expect(toggleBtn, findsOneWidget);
    expect(find.byIcon(Icons.view_sidebar_outlined), findsOneWidget);

    // Tap sidebar toggle button
    await tester.tap(toggleBtn);
    await tester.pumpAndSettle();
    expect(toggled, isTrue);
  });

  testWidgets('CsdHeaderBar renders closed state indicator for sidebar toggle button', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: claudeTheme,
          home: Scaffold(
            body: CsdHeaderBar(
              onToggleSidebar: () {},
              onOpenSettings: () {},
              onOpenQuickSwitcher: () {},
              isSidebarOpen: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sidebar_toggle_button')), findsOneWidget);
    expect(find.byIcon(Icons.view_sidebar_outlined), findsOneWidget);
  });
}
