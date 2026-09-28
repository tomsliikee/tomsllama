import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/models/ollama_model.dart';
import '../../../core/services/localization_service.dart';
import 'tomsllama_logo.dart';

class CsdHeaderBar extends ConsumerStatefulWidget {
  final VoidCallback onToggleSidebar;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenQuickSwitcher;
  final bool isZenMode;
  final List<OllamaModel> models;
  final String? selectedModel;
  final ValueChanged<String?> onModelChanged;
  final VoidCallback onManageModels;
  final double temperature;
  final ValueChanged<double>? onTemperatureChanged;

  const CsdHeaderBar({
    super.key,
    required this.onToggleSidebar,
    required this.onOpenSettings,
    required this.onOpenQuickSwitcher,
    this.isZenMode = false,
    required this.models,
    required this.selectedModel,
    required this.onModelChanged,
    required this.onManageModels,
    this.temperature = 0.7,
    this.onTemperatureChanged,
  });

  @override
  ConsumerState<CsdHeaderBar> createState() => _CsdHeaderBarState();
}

class _CsdHeaderBarState extends ConsumerState<CsdHeaderBar> {
  final GlobalKey _badgeKey = GlobalKey();
  final GlobalKey _tempKey = GlobalKey();

  void _showModelMenu(BuildContext context, AppThemeExtension appColors) async {
    final renderBox = _badgeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final targetOffset = renderBox.localToGlobal(Offset(0, renderBox.size.height + 6), ancestor: overlay);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissModelMenu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return Stack(
          children: [
            Positioned(
              left: targetOffset.dx,
              top: targetOffset.dy,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 220.0,
                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: appColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18.0,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.models.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            I18n.noModels,
                            style: AppTypography.uiControl.copyWith(
                              color: appColors.textSecondary,
                              fontSize: 12.0,
                            ),
                          ),
                        )
                      else
                        ...widget.models.map((m) {
                          final isCurrent = m.name == widget.selectedModel;
                          return InkWell(
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              widget.onModelChanged(m.name);
                            },
                            borderRadius: BorderRadius.circular(10.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                              decoration: BoxDecoration(
                                color: isCurrent ? appColors.accentSubtle : Colors.transparent,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Row(
                                children: [
                                  if (isCurrent)
                                    Icon(Icons.check, size: 14.0, color: appColors.accent)
                                  else
                                    const SizedBox(width: 14.0),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(
                                      m.name,
                                      style: AppTypography.code.copyWith(
                                        color: isCurrent ? appColors.accent : appColors.textPrimary,
                                        fontSize: 12.0,
                                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 4.0),
                      Divider(height: 1.0, color: appColors.borderSubtle),
                      const SizedBox(height: 4.0),
                      InkWell(
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          widget.onManageModels();
                        },
                        borderRadius: BorderRadius.circular(10.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                          child: Row(
                            children: [
                              Icon(Icons.tune, size: 14.0, color: appColors.textSecondary),
                              const SizedBox(width: 8.0),
                              Text(
                                I18n.manageModels,
                                style: AppTypography.uiControl.copyWith(
                                  color: appColors.textSecondary,
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTemperaturePopover(BuildContext context, AppThemeExtension appColors) async {
    final renderBox = _tempKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final targetOffset = renderBox.localToGlobal(Offset(0, renderBox.size.height + 6), ancestor: overlay);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissTemperaturePopover',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        double currentTemp = widget.temperature;
        return StatefulBuilder(
          builder: (context, setPopoverState) {
            return Stack(
              children: [
                Positioned(
                  left: targetOffset.dx - 30,
                  top: targetOffset.dy,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 250.0,
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: appColors.surface,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: appColors.borderSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 18.0,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TEMPERATUR',
                                style: AppTypography.uiControl.copyWith(
                                  color: appColors.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: appColors.accentSubtle,
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Text(
                                  currentTemp.toStringAsFixed(2),
                                  style: AppTypography.code.copyWith(
                                    color: appColors.accent,
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10.0),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: appColors.accent,
                              inactiveTrackColor: appColors.borderSubtle,
                              thumbColor: appColors.accent,
                              overlayColor: appColors.accent.withValues(alpha: 0.15),
                              trackHeight: 3.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                            ),
                            child: Slider(
                              value: currentTemp,
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              onChanged: (val) {
                                setPopoverState(() => currentTemp = val);
                                widget.onTemperatureChanged?.call(val);
                              },
                            ),
                          ),
                          const SizedBox(height: 6.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildTempPreset(
                                label: '0.2 Code',
                                isSelected: (currentTemp - 0.2).abs() < 0.01,
                                onTap: () {
                                  setPopoverState(() => currentTemp = 0.2);
                                  widget.onTemperatureChanged?.call(0.2);
                                },
                                appColors: appColors,
                              ),
                              _buildTempPreset(
                                label: '0.7 Normal',
                                isSelected: (currentTemp - 0.7).abs() < 0.01,
                                onTap: () {
                                  setPopoverState(() => currentTemp = 0.7);
                                  widget.onTemperatureChanged?.call(0.7);
                                },
                                appColors: appColors,
                              ),
                              _buildTempPreset(
                                label: '1.0 Kreativ',
                                isSelected: (currentTemp - 1.0).abs() < 0.01,
                                onTap: () {
                                  setPopoverState(() => currentTemp = 1.0);
                                  widget.onTemperatureChanged?.call(1.0);
                                },
                                appColors: appColors,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTempPreset({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppThemeExtension appColors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? appColors.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isSelected ? appColors.accent.withValues(alpha: 0.3) : appColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.uiControl.copyWith(
            color: isSelected ? appColors.accent : appColors.textSecondary,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

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
          
          const SizedBox(width: 14.0),
          
          // Model Selector Pill (Clean, without pulsating dot)
          InkWell(
            key: _badgeKey,
            onTap: () => _showModelMenu(context, appColors),
            borderRadius: BorderRadius.circular(18.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 5.0),
              decoration: BoxDecoration(
                color: appColors.surface,
                border: Border.all(color: appColors.borderSubtle),
                borderRadius: BorderRadius.circular(18.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.selectedModel ?? I18n.selectModel,
                    style: AppTypography.code.copyWith(
                      color: appColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 5.0),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 14.0,
                    color: appColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8.0),

          // Temperature Slider Pill
          if (widget.onTemperatureChanged != null)
            InkWell(
              key: _tempKey,
              onTap: () => _showTemperaturePopover(context, appColors),
              borderRadius: BorderRadius.circular(18.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
                decoration: BoxDecoration(
                  color: appColors.surface,
                  border: Border.all(color: appColors.borderSubtle),
                  borderRadius: BorderRadius.circular(18.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune,
                      size: 12.5,
                      color: appColors.textSecondary,
                    ),
                    const SizedBox(width: 5.0),
                    Text(
                      widget.temperature.toStringAsFixed(1),
                      style: AppTypography.code.copyWith(
                        color: appColors.textSecondary,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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
    const double tabWidth = 66.0;
    final int activeIndex = currentTheme == AppThemeType.claude
        ? 0
        : (currentTheme == AppThemeType.pond ? 1 : 2);

    return Container(
      width: tabWidth * 3 + 12.0,
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
