import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/localization_service.dart';
import 'tomsllama_logo.dart';

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

    if (widget.isZenMode) return const SizedBox.shrink();

    return Container(
      height: 46.0,
      decoration: BoxDecoration(
        color: appColors.background,
        border: Border(bottom: BorderSide(color: appColors.border, width: 1.0)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14.0),
          
          // Brand Logo & Title
          InkWell(
            onTap: widget.onToggleSidebar,
            borderRadius: BorderRadius.circular(4.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Row(
                children: [
                  const TomsllamaLogo(size: 20.0),
                  const SizedBox(width: 8.0),
                  Text(
                    'tomsllama',
                    style: AppTypography.uiControl.copyWith(
                      color: appColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.0,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6.0),

          // Sidebar Toggle Button next to tomsllama
          _SidebarToggleButton(
            key: const Key('sidebar_toggle_button'),
            isOpen: widget.isSidebarOpen,
            onTap: widget.onToggleSidebar,
            appColors: appColors,
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

          // Window Controls (Minimize, Maximize, Close)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildWinBtn(
                icon: Icons.remove,
                onTap: () => windowManager.minimize(),
                appColors: appColors,
              ),
              _buildWinBtn(
                icon: Icons.crop_square,
                onTap: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
                appColors: appColors,
              ),
              _buildWinBtn(
                icon: Icons.close,
                onTap: () => windowManager.close(),
                appColors: appColors,
                isClose: true,
              ),
            ],
          ),
          const SizedBox(width: 8.0),
        ],
      ),
    );
  }

  Widget _buildSlidingThemeSelector(
    BuildContext context,
    AppThemeType currentTheme,
    AppThemeExtension appColors,
  ) {
    const double tabWidth = 72.0;
    final int activeIndex = switch (currentTheme) {
      AppThemeType.claude => 0,
      AppThemeType.pond => 1,
      AppThemeType.dark => 2,
      AppThemeType.pondDark => 3,
    };

    return Container(
      width: tabWidth * 4 + 12.0,
      height: 32.0,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border.all(color: appColors.borderSubtle),
        borderRadius: BorderRadius.circular(18.0),
      ),
      child: Stack(
        children: [
          // Animated sliding background pill
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: activeIndex * tabWidth + 1.0,
            top: 0,
            bottom: 0,
            width: tabWidth,
            child: Container(
              decoration: BoxDecoration(
                color: appColors.accentSubtle,
                borderRadius: BorderRadius.circular(15.0),
                border: Border.all(color: appColors.accent.withValues(alpha: 0.25)),
              ),
            ),
          ),
          // Clickable labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
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
      height: 27.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15.0),
        child: Center(
          child: Text(
            label,
            style: AppTypography.uiControl.copyWith(
              color: isActive ? appColors.accent : appColors.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              fontSize: 12.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWinBtn({
    required IconData icon,
    required VoidCallback onTap,
    required AppThemeExtension appColors,
    bool isClose = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        child: Icon(
          icon,
          size: 14.0,
          color: isClose ? appColors.textSecondary : appColors.textSecondary,
        ),
      ),
    );
  }
}

class _SidebarToggleButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;
  final AppThemeExtension appColors;

  const _SidebarToggleButton({
    super.key,
    required this.isOpen,
    required this.onTap,
    required this.appColors,
  });

  @override
  State<_SidebarToggleButton> createState() => _SidebarToggleButtonState();
}

class _SidebarToggleButtonState extends State<_SidebarToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
    return Tooltip(
      message: I18n.toggleSidebar,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28.0,
            height: 28.0,
            decoration: BoxDecoration(
              color: _isHovered
                  ? colors.accentSubtle
                  : colors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(
                color: _isHovered
                    ? colors.accent.withValues(alpha: 0.3)
                    : colors.borderSubtle,
                width: 1.0,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.view_sidebar_outlined,
                size: 15.0,
                color: _isHovered
                    ? colors.accent
                    : (widget.isOpen ? colors.textSecondary : colors.accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
