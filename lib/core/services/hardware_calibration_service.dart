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

class ModelHardwareProfile {
  final double promptEvalSpeed;
  final double genSpeed;
  final int sampleCount;
  final bool isCalibrated;

  const ModelHardwareProfile({
    required this.promptEvalSpeed,
    required this.genSpeed,
    required this.sampleCount,
    required this.isCalibrated,
  });

  Map<String, dynamic> toJson() => {
    'prompt_eval_speed': promptEvalSpeed,
    'gen_speed': genSpeed,
    'sample_count': sampleCount,
    'is_calibrated': isCalibrated,
  };

  factory ModelHardwareProfile.fromJson(Map<String, dynamic> json) => ModelHardwareProfile(
    promptEvalSpeed: (json['prompt_eval_speed'] as num?)?.toDouble() ?? 20.0,
    genSpeed: (json['gen_speed'] as num?)?.toDouble() ?? 10.0,
    sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
    isCalibrated: (json['is_calibrated'] as bool?) ?? false,
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
    String? modelName,
  }) async {
    bool changed = false;
    double? measuredPrompt;
    double? measuredGen;

    if (promptEvalDurationNs > 0 && promptEvalCount > 5) {
      final p = promptEvalCount / (promptEvalDurationNs / 1e9);
      if (p >= 1.0 && p <= 10000.0) {
        measuredPrompt = p;
        if (!_isCalibrated) {
          _calibratedPromptEvalSpeed = measuredPrompt;
        } else {
          // Exponential moving average (alpha = 0.35)
          _calibratedPromptEvalSpeed = (0.35 * measuredPrompt) + (0.65 * _calibratedPromptEvalSpeed);
        }
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
          modelPrompt = (0.35 * measuredPrompt) + (0.65 * existing.promptEvalSpeed);
        }
        if (measuredGen != null) {
          modelGen = (0.35 * measuredGen) + (0.65 * existing.genSpeed);
        }
      }

      _modelProfiles[modelName] = ModelHardwareProfile(
        promptEvalSpeed: modelPrompt,
        genSpeed: modelGen,
        sampleCount: (existing?.sampleCount ?? 0) + 1,
        isCalibrated: true,
      );
      changed = true;
    }

    if (changed) {
      _isCalibrated = true;
      _sampleCount++;
      notifyListeners();
      await SettingsService().saveHardwareProfile(
        promptEvalSpeed: _calibratedPromptEvalSpeed,
        genSpeed: _calibratedGenSpeed,
        sampleCount: _sampleCount,
        detectedDeviceType: _deviceType,
        modelProfiles: _modelProfiles.map((k, v) => MapEntry(k, v.toJson())),
      );
    }
  }

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
    final durationDisplay = totalSec >= 60
        ? 'ca. ${(totalSec / 60.0).toStringAsFixed(1)} Min'
        : 'ca. ${totalSec}s';

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
