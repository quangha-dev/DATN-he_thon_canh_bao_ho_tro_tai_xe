import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/core/ai/stgt_drowsiness_engine.dart';
import 'package:safe_fleet_driver_ui/core/ai/temporal_safety_engine.dart';

void main() {
  test('STGT builds a 75x12 window and emits a high-risk detection', () async {
    var predictorCalls = 0;
    final engine = StgtDrowsinessEngine(
      calibrationFrames: 75,
      scorePredictor: (rows) {
        predictorCalls++;
        expect(rows, hasLength(75));
        expect(rows.every((row) => row.length == 12), isTrue);
        expect(
          rows.expand((row) => row).every((value) => value.isFinite),
          isTrue,
        );
        return 8;
      },
    );
    await engine.initialize();
    final started = DateTime(2026, 7, 27, 8);

    for (var index = 0; index < 75; index++) {
      expect(engine.ingest(_observation(started, index)), isEmpty);
    }
    expect(engine.calibrated, isTrue);

    var detections = <SafetyDetection>[];
    for (var index = 75; index < 150; index++) {
      detections = engine.ingest(
        _observation(started, index, eyeAspectRatio: 0.07),
      );
    }

    expect(predictorCalls, 1);
    expect(detections, hasLength(1));
    expect(detections.single.type, SafetyDetectionType.drowsiness);
    expect(detections.single.source, StgtDrowsinessEngine.modelSource);
    expect(detections.single.confidence, closeTo(1, 0.001));
  });

  test('STGT skips frames without an observable face', () async {
    final engine = StgtDrowsinessEngine(
      scorePredictor: (_) => 8,
      calibrationFrames: 75,
    );
    await engine.initialize();
    final started = DateTime(2026, 7, 27, 8);

    for (var index = 0; index < 10; index++) {
      engine.ingest(CabinObservation(at: started, speedKph: 40));
    }

    expect(engine.calibrationProgress, 0);
    expect(engine.calibrated, isFalse);
  });
}

CabinObservation _observation(
  DateTime started,
  int index, {
  double? eyeAspectRatio,
}) {
  final wave = (index % 10) / 1000;
  final ear = eyeAspectRatio ?? 0.28 - wave;
  return CabinObservation(
    at: started.add(Duration(milliseconds: index * 40)),
    speedKph: 40,
    leftEyeOpen: ear,
    rightEyeOpen: ear,
    mouthOpenRatio: 0.22 + wave,
    headPitchDegrees: (index % 7).toDouble(),
    headYawDegrees: (index % 5).toDouble(),
    headRollDegrees: (index % 3).toDouble(),
    irisMovement: (index % 4) / 100,
  );
}
