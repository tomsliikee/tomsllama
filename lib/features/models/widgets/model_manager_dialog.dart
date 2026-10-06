import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/ollama_model.dart';
import '../../../core/models/pull_progress.dart';
import '../../../core/services/ollama_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/services/localization_service.dart';

class ModelManagerDialog extends StatefulWidget {
  const ModelManagerDialog({super.key});

  @override
  State<ModelManagerDialog> createState() => _ModelManagerDialogState();
}

class _ModelManagerDialogState extends State<ModelManagerDialog> {
  final TextEditingController _pullController = TextEditingController();
  List<OllamaModel> _models = [];
  bool _isLoading = true;
  
  // Pull state
  StreamSubscription? _pullSub;
  PullProgress? _progress;
  bool _isPulling = false;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    List<OllamaModel> models = const [];
    try {
      models = await OllamaService().listModels();
    } catch (_) {
      // Daemon unreachable: the dialog shows its empty state.
    }
    if (!mounted) return;
    setState(() {
      _models = models;
      _isLoading = false;
    });
  }

  void _pullModel() {
    final name = _pullController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isPulling = true;
      _progress = null;
    });

    _pullSub?.cancel();
    _pullSub = OllamaService().pullModelStream(name).listen(
      (progress) {
        setState(() => _progress = progress);
      },
      onDone: () {
        setState(() {
          _isPulling = false;
          _progress = null;
        });
        _pullController.clear();
        _loadModels();
      },
      onError: (e) {
        setState(() => _isPulling = false);
        // Show error snackbar in real app
      },
    );
  }

  void _deleteModel(String name) async {
    final success = await OllamaService().deleteModel(name);
    if (success) {
      _loadModels();
    }
  }

  @override
  void dispose() {
    _pullController.dispose();
    _pullSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;

    return AppDialog(
      title: I18n.modelManager,
      width: 520.0,
      height: 580.0,
      actions: [
        AppButton(label: I18n.close, onTap: () => Navigator.of(context).pop()),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pull a model by name
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pullController,
                  enabled: !_isPulling,
                  onSubmitted: (_) => _pullModel(),
                  style: AppTypography.code.copyWith(color: appColors.textPrimary),
                  decoration: appInputDecoration(context, hint: I18n.modelHintText, mono: true),
                ),
              ),
              const SizedBox(width: AppSpace.s),
              AppButton(
                label: I18n.pull,
                isPrimary: true,
                onTap: _isPulling ? null : _pullModel,
              ),
            ],
          ),

          // Download progress: a hairline that fills with the accent
          if (_isPulling && _progress != null) ...[
            const SizedBox(height: AppSpace.m),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: _progress!.percent > 0 ? _progress!.percent : null,
                minHeight: 2.0,
                backgroundColor: appColors.border,
                color: appColors.accent,
              ),
            ),
            const SizedBox(height: AppSpace.s),
            Text(
              '${_progress!.status} · ${(_progress!.percent * 100).toStringAsFixed(1)}%',
              style: AppTypography.telemetry.copyWith(color: appColors.textSecondary, fontSize: 11.0),
            ),
          ],

          const SizedBox(height: AppSpace.xl),
          AppFieldLabel(I18n.installedModels),
          const SizedBox(height: AppSpace.s),

          Expanded(
            child: _isLoading
                ? Center(
                    child: SizedBox(
                      width: 16.0,
                      height: 16.0,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: appColors.accent),
                    ),
                  )
                : _models.isEmpty
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s),
                          child: Text(
                            I18n.noModelsInstalled,
                            style: AppTypography.small.copyWith(
                              color: appColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _models.length,
                        separatorBuilder: (_, __) => Container(height: 1.0, color: appColors.borderSubtle),
                        itemBuilder: (context, index) {
                          final model = _models[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    model.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.code.copyWith(color: appColors.textPrimary),
                                  ),
                                ),
                                Text(
                                  '${(model.size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
                                  style: AppTypography.telemetry.copyWith(
                                    color: appColors.textSecondary,
                                    fontSize: 11.0,
                                  ),
                                ),
                                const SizedBox(width: AppSpace.s),
                                AppIconButton(
                                  icon: AppIcons.delete,
                                  tooltip: I18n.delete,
                                  hoverColor: appColors.accent,
                                  onTap: () => _deleteModel(model.name),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
