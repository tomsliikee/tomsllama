import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/controllers/chat_controller.dart';
import 'localization_service.dart';
import 'settings_service.dart';

class HardwareEstimate {
  final int tokens;
  final double promptEvalSpeed;
  final int estimatedSeconds;
  final String speedDisplay;
  final String durationDisplay;
  final ChatExecutionMode mode;
  final bool isTested;

  const HardwareEstimate({
    required this.tokens,
    required this.promptEvalSpeed,
    required this.estimatedSeconds,
    required this.speedDisplay,
    required this.durationDisplay,
    required this.mode,
    this.isTested = true,
  });
}

/// What a whole reply is expected to cost, not just reading the prompt.
class ResponseEstimate {
  /// Until the first token: model load (if it is not in memory) plus prompt evaluation.
  final int waitSeconds;

  /// Until the reply is complete: [waitSeconds] plus writing a typical answer.
  final int totalSeconds;

  final double genSpeed;
  final bool isTested;

  const ResponseEstimate({
    required this.waitSeconds,
    required this.totalSeconds,
    required this.genSpeed,
    required this.isTested,
  });

  String get speedDisplay => isTested ? '~${genSpeed.round().clamp(1, 9999)} tok/s' : I18n.noSpeedTestedYet;
  String get durationDisplay => isTested ? I18n.approxDuration(totalSeconds) : '-';
}

class ModelHardwareProfile {
  final double promptEvalSpeed;
  final double genSpeed;
  final int sampleCount;
  final bool isCalibrated;

  /// Seconds a cold load took the last times it was observed; null until one was seen.
  final double? loadSeconds;

  /// Typical reply length in tokens, kept separately for replies with and
  /// without reasoning: a thinking model writes several times as much.
  final double? avgOutputTokens;
  final double? avgThinkingOutputTokens;

  const ModelHardwareProfile({
    required this.promptEvalSpeed,
    required this.genSpeed,
    required this.sampleCount,
    required this.isCalibrated,
    this.loadSeconds,
    this.avgOutputTokens,
    this.avgThinkingOutputTokens,
  });

  ModelHardwareProfile copyWith({
    double? promptEvalSpeed,
    double? genSpeed,
    int? sampleCount,
    bool? isCalibrated,
    double? loadSeconds,
    double? avgOutputTokens,
    double? avgThinkingOutputTokens,
  }) {
    return ModelHardwareProfile(
      promptEvalSpeed: promptEvalSpeed ?? this.promptEvalSpeed,
      genSpeed: genSpeed ?? this.genSpeed,
      sampleCount: sampleCount ?? this.sampleCount,
      isCalibrated: isCalibrated ?? this.isCalibrated,
      loadSeconds: loadSeconds ?? this.loadSeconds,
      avgOutputTokens: avgOutputTokens ?? this.avgOutputTokens,
      avgThinkingOutputTokens: avgThinkingOutputTokens ?? this.avgThinkingOutputTokens,
    );
  }

  Map<String, dynamic> toJson() => {
    'prompt_eval_speed': promptEvalSpeed,
    'gen_speed': genSpeed,
    'sample_count': sampleCount,
    'is_calibrated': isCalibrated,
    if (loadSeconds != null) 'load_seconds': loadSeconds,
    if (avgOutputTokens != null) 'avg_output_tokens': avgOutputTokens,
    if (avgThinkingOutputTokens != null) 'avg_thinking_output_tokens': avgThinkingOutputTokens,
  };

  factory ModelHardwareProfile.fromJson(Map<String, dynamic> json) => ModelHardwareProfile(
    promptEvalSpeed: (json['prompt_eval_speed'] as num?)?.toDouble() ?? 20.0,
    genSpeed: (json['gen_speed'] as num?)?.toDouble() ?? 10.0,
    sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
    isCalibrated: (json['is_calibrated'] as bool?) ?? false,
    loadSeconds: (json['load_seconds'] as num?)?.toDouble(),
    avgOutputTokens: (json['avg_output_tokens'] as num?)?.toDouble(),
    avgThinkingOutputTokens: (json['avg_thinking_output_tokens'] as num?)?.toDouble(),
  );
}

class HardwareCalibrationService extends ChangeNotifier {
  static final HardwareCalibrationService _instance = HardwareCalibrationService._internal();
  factory HardwareCalibrationService() => _instance;
  HardwareCalibrationService._internal() {
    _detectInitialBaseline();
  }

  double _calibratedPromptEvalSpeed = 20.0;
  double _calibratedGenSpeed = 10.0;
  int _sampleCount = 0;
  bool _isCalibrated = false;
  String _deviceType = 'unknown';
  final Map<String, ModelHardwareProfile> _modelProfiles = {};

  double get calibratedPromptEvalSpeed => _calibratedPromptEvalSpeed;
  double get calibratedGenSpeed => _calibratedGenSpeed;
  int get sampleCount => _sampleCount;
  bool get isCalibrated => _isCalibrated;
  String get deviceType => _deviceType;
  Map<String, ModelHardwareProfile> get modelProfiles => Map.unmodifiable(_modelProfiles);

  bool isModelTested(String? modelName) {
    if (modelName == null || modelName.isEmpty) return _isCalibrated;
    return _modelProfiles[modelName]?.isCalibrated ?? false;
  }

  Future<void> init() async {
    final profile = await SettingsService().loadHardwareProfile();
    if (profile != null) {
      if (profile['prompt_eval_speed'] != null) {
        _calibratedPromptEvalSpeed = (profile['prompt_eval_speed'] as num).toDouble();
        _calibratedGenSpeed = (profile['gen_speed'] as num?)?.toDouble() ?? 10.0;
        _sampleCount = (profile['sample_count'] as num?)?.toInt() ?? 1;
        _deviceType = (profile['device_type'] as String?) ?? 'persisted';
        _isCalibrated = _sampleCount > 0;
      }
      if (profile['model_profiles'] is Map) {
        final modelsMap = profile['model_profiles'] as Map;
        for (final entry in modelsMap.entries) {
          if (entry.value is Map) {
            _modelProfiles[entry.key.toString()] = ModelHardwareProfile.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
          }
        }
      }
      notifyListeners();
    } else {
      _detectInitialBaseline();
    }
  }

  void _detectInitialBaseline() {
    try {
      if (Platform.isMacOS) {
        _deviceType = 'apple_silicon';
        _calibratedPromptEvalSpeed = 160.0;
        _calibratedGenSpeed = 45.0;
        return;
      }

      if (Platform.isLinux) {
        if (File('/dev/nvidia0').existsSync()) {
          _deviceType = 'nvidia_gpu';
          _calibratedPromptEvalSpeed = 350.0;
          _calibratedGenSpeed = 75.0;
          return;
        }
        if (File('/dev/kfd').existsSync()) {
          _deviceType = 'amd_gpu';
          _calibratedPromptEvalSpeed = 250.0;
          _calibratedGenSpeed = 50.0;
          return;
        }
      }

      final cores = Platform.numberOfProcessors;
      if (cores > 8) {
        _deviceType = 'desktop_cpu';
        _calibratedPromptEvalSpeed = 35.0;
        _calibratedGenSpeed = 18.0;
      } else {
        _deviceType = 'laptop_cpu';
        _calibratedPromptEvalSpeed = 18.0;
        _calibratedGenSpeed = 10.0;
      }
    } catch (_) {
      _deviceType = 'generic_cpu';
      _calibratedPromptEvalSpeed = 20.0;
      _calibratedGenSpeed = 10.0;
    }
  }

  Future<void> recordMetrics({
    required int promptEvalCount,
    required int promptEvalDurationNs,
    required int evalCount,
    required int evalDurationNs,
    int loadDurationNs = 0,
    String? modelName,
  }) async {
    bool changed = false;
    double? measuredPrompt;
    double? measuredGen;

    // Generation speed first: it is what tells a real prompt evaluation from a cache hit.
    final double? responseGen = (evalDurationNs > 0 && evalCount > 5) ? evalCount / (evalDurationNs / 1e9) : null;
    final double referenceGen = responseGen ?? _modelProfiles[modelName]?.genSpeed ?? _calibratedGenSpeed;

    // Short prompts and sub-half-second evaluations are mostly overhead and
    // partial cache hits (a shared system prompt), so they are not sampled.
    if (promptEvalDurationNs >= _minPromptSampleNs && promptEvalCount >= _minPromptSampleTokens) {
      final p = promptEvalCount / (promptEvalDurationNs / 1e9);
      // When the prompt prefix is still in Ollama's cache it reports the full
      // token count with almost no duration, i.e. an absurd speed. Reading a
      // prompt is batched and faster than writing, but not by more than ~25x;
      // anything above that is a cache hit and says nothing about the hardware.
      final isCacheHit = p > referenceGen * _maxPromptToGenRatio;
      if (p >= 1.0 && p <= 10000.0 && !isCacheHit) {
        measuredPrompt = p;
        _calibratedPromptEvalSpeed =
            _isCalibrated ? _blendPromptSpeed(measuredPrompt, _calibratedPromptEvalSpeed) : measuredPrompt;
        changed = true;
      }
    }

    if (evalDurationNs > 0 && evalCount > 5) {
      final g = evalCount / (evalDurationNs / 1e9);
      if (g >= 0.5 && g <= 2000.0) {
        measuredGen = g;
        if (!_isCalibrated) {
          _calibratedGenSpeed = measuredGen;
        } else {
          _calibratedGenSpeed = (0.35 * measuredGen) + (0.65 * _calibratedGenSpeed);
        }
        changed = true;
      }
    }

    if (modelName != null && modelName.isNotEmpty) {
      final existing = _modelProfiles[modelName];
      double modelPrompt = measuredPrompt ?? existing?.promptEvalSpeed ?? _calibratedPromptEvalSpeed;
      double modelGen = measuredGen ?? existing?.genSpeed ?? _calibratedGenSpeed;

      if (existing != null && existing.isCalibrated) {
        if (measuredPrompt != null) {
          modelPrompt = _blendPromptSpeed(measuredPrompt, existing.promptEvalSpeed);
        }
        if (measuredGen != null) {
          modelGen = (0.35 * measuredGen) + (0.65 * existing.genSpeed);
        }
      }

      // A load of under a second is the model already sitting in memory.
      final loadSeconds = loadDurationNs / 1e9;
      final double? modelLoad = loadSeconds >= 1.0
          ? (existing?.loadSeconds == null ? loadSeconds : 0.5 * loadSeconds + 0.5 * existing!.loadSeconds!)
          : existing?.loadSeconds;

      _modelProfiles[modelName] = ModelHardwareProfile(
        promptEvalSpeed: modelPrompt,
        genSpeed: modelGen,
        sampleCount: (existing?.sampleCount ?? 0) + 1,
        isCalibrated: true,
        loadSeconds: modelLoad,
        avgOutputTokens: existing?.avgOutputTokens,
        avgThinkingOutputTokens: existing?.avgThinkingOutputTokens,
      );
      changed = true;
    }

    if (changed) {
      _isCalibrated = true;
      _sampleCount++;
      notifyListeners();
      await _persist();
    }
  }

  static const double _maxPromptToGenRatio = 25.0;
  static const int _minPromptSampleNs = 400000000;
  static const int _minPromptSampleTokens = 100;

  /// Caching can only make a prompt look faster than the hardware is, never
  /// slower. So a slower sample is believed quickly and a faster one slowly.
  static double _blendPromptSpeed(double sample, double current) {
    final alpha = sample < current ? 0.5 : 0.15;
    return alpha * sample + (1 - alpha) * current;
  }

  // Used until a model has produced replies of its own to learn from.
  static const double _defaultOutputTokens = 350.0;
  static const double _defaultThinkingOutputTokens = 1100.0;
  static const double _defaultLoadSeconds = 8.0;

  /// Remembers how long a finished reply was, so the next estimate for this
  /// model reflects how much it actually tends to write.
  Future<void> recordOutput({
    required String modelName,
    required int tokens,
    required bool hadThinking,
  }) async {
    final existing = _modelProfiles[modelName];
    if (existing == null || tokens <= 0) return;

    double blend(double? previous) => previous == null ? tokens.toDouble() : 0.3 * tokens + 0.7 * previous;
    _modelProfiles[modelName] = hadThinking
        ? existing.copyWith(avgThinkingOutputTokens: blend(existing.avgThinkingOutputTokens))
        : existing.copyWith(avgOutputTokens: blend(existing.avgOutputTokens));

    notifyListeners();
    await _persist();
  }

  Future<void> _persist() {
    return SettingsService().saveHardwareProfile(
      promptEvalSpeed: _calibratedPromptEvalSpeed,
      genSpeed: _calibratedGenSpeed,
      sampleCount: _sampleCount,
      detectedDeviceType: _deviceType,
      modelProfiles: _modelProfiles.map((k, v) => MapEntry(k, v.toJson())),
    );
  }

  /// Estimates a whole reply: loading the model if needed, reading the part of
  /// the prompt that is not cached, and writing an answer of typical length.
  ///
  /// [uncachedPromptTokens] is what Ollama still has to evaluate. On a follow-up
  /// turn that is only the new message, not the system prompt and history.
  /// [expectsThinking] is whether the model will reason before answering.
  ResponseEstimate estimateResponse({
    required int uncachedPromptTokens,
    required String? modelName,
    bool expectsThinking = false,
    bool modelLoaded = true,
  }) {
    final profile = _modelProfiles[modelName];
    if (profile == null || !profile.isCalibrated) {
      return ResponseEstimate(waitSeconds: 0, totalSeconds: 0, genSpeed: _calibratedGenSpeed, isTested: false);
    }

    final promptSpeed = profile.promptEvalSpeed.clamp(0.5, 50000.0);
    final genSpeed = profile.genSpeed.clamp(0.5, 5000.0);

    final loadSeconds = modelLoaded ? 0.0 : (profile.loadSeconds ?? _defaultLoadSeconds);
    final promptSeconds = uncachedPromptTokens <= 0 ? 0.0 : uncachedPromptTokens / promptSpeed;
    final outputTokens = expectsThinking
        ? (profile.avgThinkingOutputTokens ?? _defaultThinkingOutputTokens)
        : (profile.avgOutputTokens ?? _defaultOutputTokens);

    final wait = loadSeconds + promptSeconds;
    return ResponseEstimate(
      waitSeconds: wait.ceil(),
      totalSeconds: (wait + outputTokens / genSpeed).ceil(),
      genSpeed: genSpeed,
      isTested: true,
    );
  }

  /// Estimates only the cost of evaluating [tokens] of prompt, e.g. what an
  /// attached file adds. For how long a reply takes, use [estimateResponse].
  HardwareEstimate estimatePrompt({
    required int tokens,
    ChatExecutionMode mode = ChatExecutionMode.optimal,
    String? modelName,
  }) {
    // If a specific model is targeted and hasn't been calibrated yet, return uncalibrated notice
    if (modelName != null && modelName.isNotEmpty) {
      final profile = _modelProfiles[modelName];
      if (profile == null || !profile.isCalibrated) {
        return HardwareEstimate(
          tokens: tokens,
          promptEvalSpeed: 0.0,
          estimatedSeconds: 0,
          speedDisplay: I18n.noSpeedTestedYet,
          durationDisplay: '-',
          mode: mode,
          isTested: false,
        );
      }
    }

    final activePromptSpeed = (modelName != null && _modelProfiles[modelName]?.isCalibrated == true)
        ? _modelProfiles[modelName]!.promptEvalSpeed
        : _calibratedPromptEvalSpeed;

    final activeGenSpeed = (modelName != null && _modelProfiles[modelName]?.isCalibrated == true)
        ? _modelProfiles[modelName]!.genSpeed
        : _calibratedGenSpeed;

    if (tokens <= 0) {
      return HardwareEstimate(
        tokens: 0,
        promptEvalSpeed: activePromptSpeed,
        estimatedSeconds: 0,
        speedDisplay: '~${activePromptSpeed.round().clamp(1, 9999)} tok/s',
        durationDisplay: '<1s',
        mode: mode,
        isTested: true,
      );
    }

    // Safety buffer: 15% base buffer for thermal throttling, DDR bus jitter & cache misses
    double bufferMultiplier = 1.15;

    // Non-linear scaling: self-attention costs scale quadratically with context length
    if (tokens > 1500) {
      bufferMultiplier += ((tokens - 1500) / 10000.0).clamp(0.0, 0.45);
    }

    // Mode-specific adjustment
    int modeOverheadSec = 0;
    switch (mode) {
      case ChatExecutionMode.schnell:
        bufferMultiplier *= 0.95;
        break;
      case ChatExecutionMode.optimal:
        break;
      case ChatExecutionMode.thinking:
        // Deep reasoning generates chain-of-thought tokens before visible streaming
        final reasoningTokens = tokens > 2000 ? 150 : 90;
        modeOverheadSec = (reasoningTokens / activeGenSpeed.clamp(1.0, 100.0)).round().clamp(4, 40);
        break;
    }

    final effectiveSpeed = (activePromptSpeed / bufferMultiplier).clamp(0.5, 50000.0);
    final evalSec = (tokens / effectiveSpeed).ceil();
    final totalSec = evalSec + modeOverheadSec;

    final speedDisplay = '~${activePromptSpeed.round().clamp(1, 9999)} tok/s';
    final durationDisplay = I18n.approxDuration(totalSec);

    return HardwareEstimate(
      tokens: tokens,
      promptEvalSpeed: activePromptSpeed,
      estimatedSeconds: totalSec,
      speedDisplay: speedDisplay,
      durationDisplay: durationDisplay,
      mode: mode,
      isTested: true,
    );
  }
}

final hardwareCalibrationProvider = ChangeNotifierProvider<HardwareCalibrationService>((ref) {
  return HardwareCalibrationService();
});
