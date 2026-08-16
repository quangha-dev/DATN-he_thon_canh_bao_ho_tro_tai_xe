import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/core/ai/stgt_drowsiness_engine.dart';
import 'package:safe_fleet_driver_ui/core/ai/temporal_safety_engine.dart';

void main() {
  test('drowsiness score is exposed as risk levels from 1 to 10', () {
    expect(drowsinessRiskLevel(0), 1);
    expect(drowsinessRiskLevel(3.5), 4);
    expect(drowsinessRiskLevel(6), 6);
    expect(drowsinessRiskLevel(9.2), 10);
    expect(drowsinessRiskLevel(20), 10);
    expect(drowsinessRiskLabel(3), 'Tỉnh táo');
    expect(drowsinessRiskLabel(4), 'Cần chú ý');
    expect(drowsinessRiskLabel(6), 'Nguy hiểm');
    expect(drowsinessRiskLabel(9), 'Báo động');
  });

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

  test('desktop yawn guardrail raises score and emits a warning', () async {
    final engine = StgtDrowsinessEngine(
      calibrationFrames: 75,
      scorePredictor: (_) => 1,
    );
    await engine.initialize();
    final started = DateTime(2026, 7, 27, 8);

    for (var index = 0; index < 75; index++) {
      engine.ingest(_observation(started, index));
    }

    final detections = <SafetyDetection>[];
    for (var index = 75; index < 150; index++) {
      detections.addAll(
        engine.ingest(_observation(started, index, mouthOpenRatio: 0.75)),
      );
    }

    expect(detections, hasLength(1));
    expect(detections.single.reason, contains('ngáp'));
    expect(engine.rawScore, 6);
    expect(engine.score, 6);
  });

  test(
    'desktop false-positive guard suppresses high score with normal eyes',
    () async {
      final engine = StgtDrowsinessEngine(
        calibrationFrames: 75,
        scorePredictor: (_) => 8,
      );
      await engine.initialize();
      final started = DateTime(2026, 7, 27, 8);

      for (var index = 0; index < 75; index++) {
        engine.ingest(_observation(started, index));
      }

      var detections = <SafetyDetection>[];
      for (var index = 75; index < 150; index++) {
        detections = engine.ingest(_observation(started, index));
      }

      expect(detections, isEmpty);
      expect(engine.rawScore, 2);
      expect(engine.score, 2);
      expect(engine.statusText, contains('Tỉnh táo'));
    },
  );

  test(
    'slightly drooping eyes raise score and warn within one second',
    () async {
      final engine = StgtDrowsinessEngine(
        calibrationFrames: 75,
        scorePredictor: (_) => 1,
      );
      await engine.initialize();
      final started = DateTime(2026, 7, 27, 8);

      for (var index = 0; index < 75; index++) {
        engine.ingest(_observation(started, index));
      }

      // Fill the fixed 3-second model window while the driver is alert.
      for (var index = 75; index < 150; index++) {
        engine.ingest(_observation(started, index));
      }

      final detections = <SafetyDetection>[];
      for (var index = 150; index < 175; index++) {
        detections.addAll(
          engine.ingest(_observation(started, index, eyeAspectRatio: 0.255)),
        );
        if (detections.isNotEmpty) break;
      }

      expect(detections, hasLength(1));
      expect(detections.single.reason, contains('mí mắt sụp'));
      expect(
        detections.single.detectedAt.difference(started).inMilliseconds -
            150 * 40,
        lessThanOrEqualTo(1000),
      );
      expect(engine.rawScore, 5);
      expect(engine.score, 5);
    },
  );

  test('resamples a slow camera stream to the model 25 FPS timeline', () async {
    var predictorCalls = 0;
    final engine = StgtDrowsinessEngine(
      calibrationFrames: 75,
      scorePredictor: (_) {
        predictorCalls++;
        return 1;
      },
    );
    await engine.initialize();
    final started = DateTime(2026, 7, 27, 8);

    for (var index = 0; index < 75; index++) {
      engine.ingest(_observation(started, index));
    }
    final monitoringStarted = started.add(const Duration(seconds: 3));
    for (var index = 0; index <= 30; index++) {
      engine.ingest(
        _observationAt(
          monitoringStarted.add(Duration(milliseconds: index * 100)),
        ),
      );
    }

    expect(predictorCalls, greaterThanOrEqualTo(1));
  });
}

CabinObservation _observation(
  DateTime started,
  int index, {
  double? eyeAspectRatio,
  double? mouthOpenRatio,
}) {
  final wave = (index % 10) / 1000;
  final ear = eyeAspectRatio ?? 0.28 - wave;
  return CabinObservation(
    at: started.add(Duration(milliseconds: index * 40)),
    speedKph: 40,
    leftEyeOpen: ear,
    rightEyeOpen: ear,
    mouthOpenRatio: mouthOpenRatio ?? 0.22 + wave,
    headPitchDegrees: (index % 7).toDouble(),
    headYawDegrees: (index % 5).toDouble(),
    headRollDegrees: (index % 3).toDouble(),
    irisMovement: (index % 4) / 100,
  );
}

CabinObservation _observationAt(DateTime at) => CabinObservation(
  at: at,
  speedKph: 40,
  leftEyeOpen: 0.28,
  rightEyeOpen: 0.28,
  mouthOpenRatio: 0.22,
  headPitchDegrees: 2,
  headYawDegrees: 1,
  headRollDegrees: 0,
);
