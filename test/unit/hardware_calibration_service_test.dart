import 'package:flutter_test/flutter_test.dart';
import 'package:tomsllama/core/services/hardware_calibration_service.dart';
import 'package:tomsllama/core/services/localization_service.dart';
import 'package:tomsllama/features/chat/controllers/chat_controller.dart';

void main() {
  group('HardwareCalibrationService Tests', () {
    late HardwareCalibrationService service;

    setUp(() {
      service = HardwareCalibrationService();
    });

    test('service initializes with valid baseline parameters', () {
      expect(service.calibratedPromptEvalSpeed, greaterThan(0.0));
      expect(service.calibratedGenSpeed, greaterThan(0.0));
      expect(service.deviceType, isNotEmpty);
    });

    test('estimatePrompt incorporates safety buffer and mode differences', () {
      const tokens = 1000;

      final estSchnell = service.estimatePrompt(tokens: tokens, mode: ChatExecutionMode.schnell);
      final estOptimal = service.estimatePrompt(tokens: tokens, mode: ChatExecutionMode.optimal);
      final estThinking = service.estimatePrompt(tokens: tokens, mode: ChatExecutionMode.thinking);

      expect(estSchnell.tokens, equals(tokens));
      expect(estOptimal.tokens, equals(tokens));
      expect(estThinking.tokens, equals(tokens));

      // Schnell should be faster or equal to optimal
      expect(estSchnell.estimatedSeconds, lessThanOrEqualTo(estOptimal.estimatedSeconds));

      // Thinking mode includes reasoning startup latency and should take longer than optimal
      expect(estThinking.estimatedSeconds, greaterThan(estOptimal.estimatedSeconds));

      // Verify formatted string outputs
      expect(estOptimal.speedDisplay, startsWith('~'));
      expect(estOptimal.speedDisplay, endsWith('tok/s'));
      expect(estOptimal.durationDisplay, startsWith('ca. '));
    });

    test('large token contexts incur non-linear scaling penalty', () {
      final small = service.estimatePrompt(tokens: 500, mode: ChatExecutionMode.optimal);
      final large = service.estimatePrompt(tokens: 6000, mode: ChatExecutionMode.optimal);

      // 6000 is 12x 500 tokens, but because of quadratic context scaling buffer, it takes more than 12x
      expect(large.estimatedSeconds, greaterThan(small.estimatedSeconds * 12));
    });

    test('recordMetrics updates EMA calibration and marks calibrated', () async {
      final initialPromptSpeed = service.calibratedPromptEvalSpeed;
      final initialSampleCount = service.sampleCount;

      // Simulate a real Ollama stream completion chunk: 100 tokens evaluated in 5.0 seconds = 20 tok/s
      await service.recordMetrics(
        promptEvalCount: 100,
        promptEvalDurationNs: 5000000000, // 5s
        evalCount: 50,
        evalDurationNs: 5000000000, // 5s = 10 tok/s
      );

      expect(service.isCalibrated, isTrue);
      expect(service.sampleCount, equals(initialSampleCount + 1));
      expect(service.calibratedPromptEvalSpeed, isNot(equals(0.0)));
      expect(initialPromptSpeed, greaterThan(0.0));
    });

    test('per-model speed profile starts uncalibrated and calibrates upon recording', () async {
      const modelName = 'deepseek-r1:14b';
      expect(service.isModelTested(modelName), isFalse);

      final uncalibratedEst = service.estimatePrompt(tokens: 1000, modelName: modelName);
      expect(uncalibratedEst.isTested, isFalse);
      expect(uncalibratedEst.speedDisplay, equals(I18n.noSpeedTestedYet));
      expect(uncalibratedEst.durationDisplay, equals('-'));

      // Now record metrics for this model
      await service.recordMetrics(
        promptEvalCount: 50,
        promptEvalDurationNs: 2000000000, // 25 tok/s
        evalCount: 30,
        evalDurationNs: 1000000000, // 30 tok/s
        modelName: modelName,
      );

      expect(service.isModelTested(modelName), isTrue);
      final calibratedEst = service.estimatePrompt(tokens: 1000, modelName: modelName);
      expect(calibratedEst.isTested, isTrue);
      expect(calibratedEst.speedDisplay, startsWith('~'));
      expect(calibratedEst.speedDisplay, contains('tok/s'));
      expect(calibratedEst.durationDisplay, startsWith('ca. '));
    });
  });
}
