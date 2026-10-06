import 'package:flutter/material.dart';
import '../../../core/constants/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/services/localization_service.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../../core/widgets/tomsllama_logo.dart';

class CsdHeaderBar extends ConsumerStatefulWidget {
  final VoidCallback onToggleSidebar;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenQuickSwitcher;
  final bool isZenMode;
  final bool isSidebarOpen;

  const CsdHeaderBar({
    super.key,
    required this.onToggleSidebar,
    required this.onOpenSettings,
    required this.onOpenQuickSwitcher,
    this.isZenMode = false,
    this.isSidebarOpen = true,
  });

  @override
  ConsumerState<CsdHeaderBar> createState() => _CsdHeaderBarState();
}

class _CsdHeaderBarState extends ConsumerState<CsdHeaderBar> {
  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final currentTheme = ref.watch(themeProvider);
    final isGenerating = ref.watch(chatProvider.select((s) => s.generatingConversationIds.isNotEmpty));
    // macOS draws its own traffic lights top-left, over the header.
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;

    if (widget.isZenMode) return const SizedBox.shrink();

    return Container(
      height: 46.0,
      decoration: BoxDecoration(
        color: appColors.background,
        border: Border(bottom: BorderSide(color: appColors.border, width: 1.0)),
      ),
      child: Row(
        children: [
          SizedBox(width: isMac ? 78.0 : 14.0),
          
          // Brand Logo & Title
          InkWell(
            onTap: widget.onToggleSidebar,
            borderRadius: BorderRadius.circular(4.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Row(
                children: [
                  TomsllamaLogo(size: 20.0, breathing: isGenerating),
                  const SizedBox(width: 8.0),
                  Text(
                    'tomsllama',
                    style: AppTypography.title.copyWith(
                      color: appColors.textPrimary,
                      fontSize: 16.5,
                      height: 1.0,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6.0),

          // Sidebar Toggle Button next to tomsllama
          AppIconButton(
            key: const Key('sidebar_toggle_button'),
            icon: AppIcons.sidebar,
            tooltip: I18n.toggleSidebar,
            color: widget.isSidebarOpen ? appColors.textSecondary : appColors.accent,
            hoverColor: appColors.accent,
            onTap: widget.onToggleSidebar,
          ),
          
          // Drag Window Area (Left)
          Expanded(
            child: DragToMoveArea(
              child: Container(color: Colors.transparent),
            ),
          ),
          
          // Theme Selector (Sliding Segmented Control in center)
          _buildSlidingThemeSelector(context, currentTheme, appColors),

          // Drag Window Area (Right)
          Expanded(
            child: DragToMoveArea(
              child: Container(color: Colors.transparent),
            ),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconButton(
                key: const Key('settings_button'),
                icon: AppIcons.settings,
                tooltip: I18n.settingsTooltip,
                onTap: widget.onOpenSettings,
              ),
              // Window controls: not on macOS, where the system provides them.
              if (!isMac) ...[
                // A hairline keeps app actions apart from window controls
                Container(
                  width: 1.0,
                  height: 14.0,
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  color: appColors.border,
                ),
                AppIconButton(
                  icon: AppIcons.windowMinimize,
                  size: 14.0,
                  onTap: () => windowManager.minimize(),
                ),
                AppIconButton(
                  icon: AppIcons.windowMaximize,
                  size: 13.0,
                  onTap: () async {
                    if (await windowManager.isMaximized()) {
                      windowManager.unmaximize();
                    } else {
                      windowManager.maximize();
                    }
                  },
                ),
                AppIconButton(
                  icon: AppIcons.close,
                  size: 14.0,
                  hoverColor: appColors.accent,
                  onTap: () => windowManager.close(),
                ),
              ],
            ],
          ),
          SizedBox(width: isMac ? 14.0 : 8.0),
        ],
      ),
    );
  }

  Widget _buildSlidingThemeSelector(
    BuildContext context,
    AppThemeType currentTheme,
    AppThemeExtension appColors,
  ) {
    const double tabWidth = 76.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int activeIndex = switch (currentTheme) {
      AppThemeType.claude => 0,
      AppThemeType.pond => 1,
      AppThemeType.dark => 2,
      AppThemeType.pondDark => 3,
    };

    return Container(
      width: tabWidth * 4 + 8.0,
      height: 30.0,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border.all(color: appColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Stack(
        children: [
          // Animated sliding background pill
          AnimatedPositioned(
            duration: AppMotion.slow,
            curve: AppMotion.standard,
            left: activeIndex * tabWidth,
            top: 0,
            bottom: 0,
            width: tabWidth,
            child: Container(
              // Same neutral thumb as the Chats/Workspaces switch. The accent is
              // kept for things that act, not for showing which option is on.
              decoration: BoxDecoration(
                color: isDark
                    ? Color.alphaBlend(Colors.black.withValues(alpha: 0.45), appColors.surface)
                    : Color.alphaBlend(appColors.textPrimary.withValues(alpha: 0.07), appColors.surface),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: appColors.border),
              ),
            ),
          ),
          // Clickable labels
          Padding(
            padding: EdgeInsets.zero,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThemeTab(
                  label: 'Claude',
                  isActive: activeIndex == 0,
                  width: tabWidth,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(AppThemeType.claude),
                  appColors: appColors,
                ),
                _buildThemeTab(
                  label: 'Pond',
                  isActive: activeIndex == 1,
                  width: tabWidth,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(AppThemeType.pond),
                  appColors: appColors,
                ),
                _buildThemeTab(
                  label: 'Dark',
                  isActive: activeIndex == 2,
                  width: tabWidth,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(AppThemeType.dark),
                  appColors: appColors,
                ),
                _buildThemeTab(
                  label: 'Pond Dark',
                  isActive: activeIndex == 3,
                  width: tabWidth,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(AppThemeType.pondDark),
                  appColors: appColors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTab({
    required String label,
    required bool isActive,
    required double width,
    required VoidCallback onTap,
    required AppThemeExtension appColors,
  }) {
    return SizedBox(
      width: width,
      height: 22.0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: AppMotion.base,
              style: AppTypography.label.copyWith(
                color: isActive ? appColors.textPrimary : appColors.textSecondary,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                fontSize: 11.0,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
