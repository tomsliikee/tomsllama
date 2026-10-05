import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/ollama_model.dart';
import '../../../core/models/pull_progress.dart';
import '../../../core/services/ollama_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/frosted_glass.dart';
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
    final models = await OllamaService().listModels();
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

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      child: FrostedGlass(
        width: 500,
        height: 600,
        borderRadius: BorderRadius.circular(16.0),
        borderColor: appColors.borderSubtle,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              I18n.modelManager,
              style: AppTypography.headline.copyWith(color: appColors.textPrimary, fontSize: 20.0),
            ),
            const SizedBox(height: 24.0),
            
            // Pull Model Section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pullController,
                    enabled: !_isPulling,
                    style: AppTypography.uiControl.copyWith(color: appColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: I18n.modelHintText,
                      hintStyle: TextStyle(color: appColors.textSecondary),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: appColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: appColors.border),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                ElevatedButton(
                  onPressed: _isPulling ? null : _pullModel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.accent,
                    foregroundColor: appColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  ),
                  child: Text(I18n.pull),
                ),
              ],
            ),
            
            // Progress Bar
            if (_isPulling && _progress != null) ...[
              const SizedBox(height: 16.0),
              LinearProgressIndicator(
                value: _progress!.percent > 0 ? _progress!.percent : null,
                backgroundColor: appColors.border,
                color: appColors.accent,
              ),
              const SizedBox(height: 8.0),
              Text(
                '${_progress!.status} ${(_progress!.percent * 100).toStringAsFixed(1)}%',
                style: AppTypography.telemetry.copyWith(color: appColors.textSecondary),
              ),
            ],
            
            const Divider(height: 48.0),
            
            // Installed Models List
            Text(
              I18n.installedModels,
              style: AppTypography.uiControl.copyWith(color: appColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12.0),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _models.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final model = _models[index];
                        return ListTile(
                          title: Text(model.name, style: AppTypography.uiControl.copyWith(color: appColors.textPrimary)),
                          subtitle: Text(
                            '${(model.size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
                            style: AppTypography.telemetry.copyWith(color: appColors.textSecondary),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            onPressed: () => _deleteModel(model.name),
                          ),
                        );
                      },
                    ),
            ),
            
            // Close Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(I18n.close, style: TextStyle(color: appColors.textPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
