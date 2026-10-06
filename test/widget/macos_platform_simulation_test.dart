import 'package:tomsllama/core/constants/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/theme/claude_theme.dart';
import 'package:tomsllama/features/shell/widgets/csd_header_bar.dart';

void main() {
  group('macOS Platform Simulation Tests', () {
    testWidgets('macOS header reserves 78px traffic-lights padding and hides custom window controls', (WidgetTester tester) async {
      final macTheme = claudeTheme.copyWith(platform: TargetPlatform.macOS);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: macTheme,
            home: Scaffold(
              body: CsdHeaderBar(
                onToggleSidebar: () {},
                onOpenSettings: () {},
                onOpenQuickSwitcher: () {},
                isSidebarOpen: true,
              ),
            ),
          ),
        ),
      );

      // Verify brand logo and title are rendered
      expect(find.text('tomsllama'), findsOneWidget);
      expect(find.byKey(const Key('sidebar_toggle_button')), findsOneWidget);

      // Verify that on macOS, custom minimize, maximize, and close buttons are HIDDEN
      // because native Cocoa/AppKit traffic lights occupy the top-left area.
      expect(find.byIcon(AppIcons.windowMinimize), findsNothing);
      expect(find.byIcon(AppIcons.windowMaximize), findsNothing);
      expect(find.byIcon(AppIcons.close), findsNothing);

      // Verify leading inset is 78.0 px on macOS
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final leadingInset = sizedBoxes.firstWhere((sb) => sb.width == 78.0);
      expect(leadingInset.width, equals(78.0));
    });

    testWidgets('Linux/Windows header uses 14px leading padding and renders window controls', (WidgetTester tester) async {
      final linuxTheme = claudeTheme.copyWith(platform: TargetPlatform.linux);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: linuxTheme,
            home: Scaffold(
              body: CsdHeaderBar(
                onToggleSidebar: () {},
                onOpenSettings: () {},
                onOpenQuickSwitcher: () {},
                isSidebarOpen: true,
              ),
            ),
          ),
        ),
      );

      // Verify window controls ARE present on Linux
      expect(find.byIcon(AppIcons.windowMinimize), findsOneWidget);
      expect(find.byIcon(AppIcons.windowMaximize), findsOneWidget);
      expect(find.byIcon(AppIcons.close), findsOneWidget);

      // Verify leading inset is 14.0 px on Linux
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final leadingInset = sizedBoxes.firstWhere((sb) => sb.width == 14.0);
      expect(leadingInset.width, equals(14.0));
    });

    testWidgets('macOS Command key (Meta) shortcuts trigger registered actions', (WidgetTester tester) async {
      bool sidebarToggled = false;
      bool quickSwitcherOpened = false;
      bool newChatOpened = false;
      bool settingsOpened = false;

      // Build a minimal shortcut test harness mimicking desktop_shell.dart
      await tester.pumpWidget(
        MaterialApp(
          home: Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.keyB, meta: true): _TestSidebarIntent(),
              SingleActivator(LogicalKeyboardKey.keyK, meta: true): _TestSearchIntent(),
              SingleActivator(LogicalKeyboardKey.keyN, meta: true): _TestNewChatIntent(),
              SingleActivator(LogicalKeyboardKey.comma, meta: true): _TestSettingsIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                _TestSidebarIntent: CallbackAction<_TestSidebarIntent>(onInvoke: (_) => sidebarToggled = true),
                _TestSearchIntent: CallbackAction<_TestSearchIntent>(onInvoke: (_) => quickSwitcherOpened = true),
                _TestNewChatIntent: CallbackAction<_TestNewChatIntent>(onInvoke: (_) => newChatOpened = true),
                _TestSettingsIntent: CallbackAction<_TestSettingsIntent>(onInvoke: (_) => settingsOpened = true),
              },
              child: const Focus(
                autofocus: true,
                child: Scaffold(
                  body: Text('macOS Shortcuts Test'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger Cmd+B (Meta + B)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(sidebarToggled, isTrue, reason: 'Cmd+B should toggle sidebar');

      // Trigger Cmd+K (Meta + K)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(quickSwitcherOpened, isTrue, reason: 'Cmd+K should open quick switcher');

      // Trigger Cmd+N (Meta + N)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(newChatOpened, isTrue, reason: 'Cmd+N should start new chat');

      // Trigger Cmd+, (Meta + Comma)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(settingsOpened, isTrue, reason: 'Cmd+, should open settings');
    });
  });
}

class _TestSidebarIntent extends Intent { const _TestSidebarIntent(); }
class _TestSearchIntent extends Intent { const _TestSearchIntent(); }
class _TestNewChatIntent extends Intent { const _TestNewChatIntent(); }
class _TestSettingsIntent extends Intent { const _TestSettingsIntent(); }
