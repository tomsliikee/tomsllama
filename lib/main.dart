import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'dart:io';

import 'core/theme/app_theme.dart';
import 'features/shell/widgets/desktop_shell.dart';
import 'core/services/database_service.dart';
import 'core/services/localization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SQLite database
  await DatabaseService().database;

  // Initialize Window Manager
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    try {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1200, 800),
        minimumSize: Size(850, 600),
        center: true,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        title: 'tomsllama',
      );
      
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint('Window manager initialization warning: $e');
    }

    // Setup Tray safely
    try {
      await trayManager.setIcon('assets/app_icon.png');
      final menu = Menu(
        items: [
          MenuItem(key: 'show_window', label: I18n.showApp),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: I18n.exitApp),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('Tray manager initialization warning: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: TomsllamaApp(),
    ),
  );
}

class TomsllamaApp extends ConsumerWidget {
  const TomsllamaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeProvider);
    final themeData = getThemeData(themeType);

    return MaterialApp(
      title: 'tomsllama',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      home: const DesktopShell(),
    );
  }
}
