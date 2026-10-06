import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/ollama_model.dart';
import '../../../../core/models/pull_progress.dart';
import '../../../../core/services/ollama_service.dart';
import '../../../../core/services/localization_service.dart';
import '../../settings/controllers/settings_controller.dart';

class ModelState {
  final List<OllamaModel> models;
  final String? selectedModel;
  final bool isLoading;
  final PullProgress? activePull;
  final String? errorMessage;

  const ModelState({
    this.models = const [],
    this.selectedModel,
    this.isLoading = false,
    this.activePull,
    this.errorMessage,
  });

  ModelState copyWith({
    List<OllamaModel>? models,
    String? selectedModel,
    bool? isLoading,
    PullProgress? activePull,
    bool clearPull = false,
    String? errorMessage,
  }) {
    return ModelState(
      models: models ?? this.models,
      selectedModel: selectedModel ?? this.selectedModel,
      isLoading: isLoading ?? this.isLoading,
      activePull: clearPull ? null : (activePull ?? this.activePull),
      errorMessage: errorMessage,
    );
  }
}

class ModelNotifier extends StateNotifier<ModelState> {
  final OllamaService _service = OllamaService();

  final Ref _ref;

  ModelNotifier(this._ref) : super(const ModelState()) {
    loadModels();
  }

  Future<void> loadModels() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _service.listModels();
      if (!mounted) return;
      String? selected = state.selectedModel;
      if (selected != null && !list.any((m) => m.name == selected)) {
        selected = null;
      }
      if (selected == null && list.isNotEmpty) {
        // The configured default wins; otherwise prefer qwen2.5:3b or qwen2.5-coder:3b if present
        final configured = _ref.read(appSettingsProvider).defaultModel;
        final preferred = list.firstWhere(
          (m) => m.name == configured,
          orElse: () => list.firstWhere(
            (m) => m.name.contains('qwen2.5:3b') || m.name.contains('qwen2.5-coder:3b'),
            orElse: () => list.first,
          ),
        );
        selected = preferred.name;
      }
      state = state.copyWith(
        models: list,
        selectedModel: selected,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: I18n.ollamaUnreachable(_service.baseUrl),
      );
    }
  }

  void selectModel(String modelName) {
    state = state.copyWith(selectedModel: modelName);
  }

  Future<void> pullModel(String modelName) async {
    try {
      await for (final progress in _service.pullModelStream(modelName)) {
        state = state.copyWith(activePull: progress);
      }
      state = state.copyWith(clearPull: true);
      await loadModels();
    } catch (e) {
      state = state.copyWith(
        clearPull: true,
        errorMessage: 'Failed to pull model: $e',
      );
    }
  }

  Future<bool> deleteModel(String modelName) async {
    final success = await _service.deleteModel(modelName);
    if (success) {
      await loadModels();
    }
    return success;
  }
}

final modelProvider = StateNotifierProvider<ModelNotifier, ModelState>((ref) {
  return ModelNotifier(ref);
});
