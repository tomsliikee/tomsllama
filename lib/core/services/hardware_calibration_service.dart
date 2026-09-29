import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/controllers/chat_controller.dart';
import 'settings_service.dart';

class HardwareEstimate {
  final int tokens;
  final double promptEvalSpeed;
  final int estimatedSeconds;
  final String speedDisplay;
  final String durationDisplay;
  final ChatExecutionMode mode;

  const HardwareEstimate({
    required this.tokens,
    required this.promptEvalSpeed,
    required this.estimatedSeconds,
    required this.speedDisplay,
    required this.durationDisplay,
    required this.mode,
  });
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

  double get calibratedPromptEvalSpeed => _calibratedPromptEvalSpeed;
  double get calibratedGenSpeed => _calibratedGenSpeed;
  int get sampleCount => _sampleCount;
  bool get isCalibrated => _isCalibrated;
  String get deviceType => _deviceType;

  Future<void> init() async {
    final profile = await SettingsService().loadHardwareProfile();
    if (profile != null && profile['prompt_eval_speed'] != null) {
      _calibratedPromptEvalSpeed = (profile['prompt_eval_speed'] as num).toDouble();
      _calibratedGenSpeed = (profile['gen_speed'] as num?)?.toDouble() ?? 10.0;
      _sampleCount = (profile['sample_count'] as num?)?.toInt() ?? 1;
      _deviceType = (profile['device_type'] as String?) ?? 'persisted';
      _isCalibrated = _sampleCount > 0;
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

    if (promptEvalDurationNs > 0 && promptEvalCount > 5) {
      final measuredPrompt = promptEvalCount / (promptEvalDurationNs / 1e9);
      if (measuredPrompt >= 1.0 && measuredPrompt <= 10000.0) {
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
      final measuredGen = evalCount / (evalDurationNs / 1e9);
      if (measuredGen >= 0.5 && measuredGen <= 2000.0) {
        if (!_isCalibrated) {
          _calibratedGenSpeed = measuredGen;
        } else {
          _calibratedGenSpeed = (0.35 * measuredGen) + (0.65 * _calibratedGenSpeed);
        }
        changed = true;
      }
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
      );
    }
  }

  HardwareEstimate estimatePrompt({
    required int tokens,
    ChatExecutionMode mode = ChatExecutionMode.optimal,
  }) {
    if (tokens <= 0) {
      return HardwareEstimate(
        tokens: 0,
        promptEvalSpeed: _calibratedPromptEvalSpeed,
        estimatedSeconds: 0,
        speedDisplay: '~${_calibratedPromptEvalSpeed.round().clamp(1, 9999)} tok/s',
        durationDisplay: '<1s',
        mode: mode,
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
        modeOverheadSec = (reasoningTokens / _calibratedGenSpeed.clamp(1.0, 100.0)).round().clamp(4, 40);
        break;
    }

    final effectiveSpeed = (_calibratedPromptEvalSpeed / bufferMultiplier).clamp(0.5, 50000.0);
    final evalSec = (tokens / effectiveSpeed).ceil();
    final totalSec = evalSec + modeOverheadSec;

    final speedDisplay = '~${_calibratedPromptEvalSpeed.round().clamp(1, 9999)} tok/s';
    final durationDisplay = totalSec >= 60
        ? 'ca. ${(totalSec / 60.0).toStringAsFixed(1)} Min'
        : 'ca. ${totalSec}s';

    return HardwareEstimate(
      tokens: tokens,
      promptEvalSpeed: _calibratedPromptEvalSpeed,
      estimatedSeconds: totalSec,
      speedDisplay: speedDisplay,
      durationDisplay: durationDisplay,
      mode: mode,
    );
  }
}

final hardwareCalibrationProvider = ChangeNotifierProvider<HardwareCalibrationService>((ref) {
  return HardwareCalibrationService();
});
