import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_fleet_driver_ui/core/ai/stgt_drowsiness_engine.dart';
import 'package:safe_fleet_driver_ui/core/ai/temporal_safety_engine.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled fold-1 TFLite model matches the reference output', (
    tester,
  ) async {
    final interpreter = await Interpreter.fromAsset(
      StgtDrowsinessEngine.assetPath,
    );
    addTearDown(interpreter.close);

    expect(interpreter.getInputTensor(0).shape, [1, 75, 12]);
    expect(interpreter.getOutputTensor(0).shape, [1, 1]);

    final input = [List.generate(75, (_) => List<double>.filled(12, 0))];
    final output = [List<double>.filled(1, 0)];
    interpreter.run(input, output);

    // Expected score was measured from best_model_fold_1.pth and its ONNX
    // export using the same all-zero [1, 75, 12] tensor.
    expect(output[0][0], closeTo(0.97471893, 0.02));
  });

  testWidgets('bundled model produces finite, input-dependent 1-10 scores', (
    tester,
  ) async {
    final interpreter = await Interpreter.fromAsset(
      StgtDrowsinessEngine.assetPath,
    );
    addTearDown(interpreter.close);

    double run(double Function(int frame, int feature) value) {
      final input = [
        List.generate(
          75,
          (frame) => List.generate(12, (feature) => value(frame, feature)),
        ),
      ];
      final output = [List<double>.filled(1, 0)];
      interpreter.run(input, output);
      return output[0][0];
    }

    final neutral = run((_, _) => 0);
    final droopingEyes = run((_, feature) => feature == 0 ? -3 : 0);
    final yawning = run((_, feature) => feature == 1 ? 3 : 0);

    for (final score in [neutral, droopingEyes, yawning]) {
      expect(score.isFinite, isTrue);
      expect(score, inInclusiveRange(0, 10));
    }
    expect(droopingEyes, greaterThan(neutral));
    expect(yawning, greaterThan(neutral));
  });

  testWidgets('STGT engine invokes the bundled model with a 75x12 window', (
    tester,
  ) async {
    final engine = StgtDrowsinessEngine(calibrationFrames: 75);
    await engine.initialize();
    addTearDown(engine.close);
    final started = DateTime(2026, 8, 15, 8);

    CabinObservation observation(int index, {double ear = 0.28}) {
      final wave = (index % 10) / 1000;
      return CabinObservation(
        at: started.add(Duration(milliseconds: index * 40)),
        speedKph: 40,
        leftEyeOpen: ear - wave,
        rightEyeOpen: ear - wave,
        mouthOpenRatio: 0.22 + wave,
        headPitchDegrees: (index % 7).toDouble(),
        headYawDegrees: (index % 5).toDouble(),
        headRollDegrees: (index % 3).toDouble(),
      );
    }

    for (var index = 0; index < 75; index++) {
      engine.ingest(observation(index));
    }
    for (var index = 75; index < 155; index++) {
      engine.ingest(observation(index, ear: 0.20));
    }

    expect(engine.ready, isTrue);
    expect(engine.calibrated, isTrue);
    expect(engine.scoreHistory, isNotEmpty);
    expect(engine.rawScore.isFinite, isTrue);
    expect(engine.rawScore, inInclusiveRange(0, 10));
    expect(engine.score, greaterThanOrEqualTo(5));
    expect(engine.statusText, contains('mí mắt sụp'));
  });

  testWidgets('built-in-only model keeps inference lightweight', (
    tester,
  ) async {
    final interpreter = await Interpreter.fromAsset(
      StgtDrowsinessEngine.assetPath,
    );
    addTearDown(interpreter.close);
    final input = [
      List.generate(
        75,
        (frame) => List.generate(
          12,
          (feature) => ((frame + feature) % 7 - 3).toDouble() / 3,
        ),
      ),
    ];
    final output = [List<double>.filled(1, 0)];
    for (var index = 0; index < 3; index++) {
      interpreter.run(input, output);
    }

    final stopwatch = Stopwatch()..start();
    for (var index = 0; index < 20; index++) {
      interpreter.run(input, output);
    }
    stopwatch.stop();
    final averageMs = stopwatch.elapsedMicroseconds / 20 / 1000;
    // ignore: avoid_print
    print('STGT average inference: ${averageMs.toStringAsFixed(2)} ms');

    // A generous regression ceiling for the x86 Android emulator. Real ARM
    // devices are expected to be substantially faster.
    expect(averageMs, lessThan(200));
  });
}
