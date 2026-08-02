import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/core/ai/temporal_safety_engine.dart';

void main() {
  test('closed eyes trigger one drowsiness alert and respect cooldown', () {
    final engine = TemporalSafetyEngine();
    final started = DateTime(2026, 7, 27, 8);

    expect(
      engine.ingest(
        CabinObservation(
          at: started,
          speedKph: 40,
          leftEyeOpen: 0.1,
          rightEyeOpen: 0.12,
        ),
      ),
      isEmpty,
    );
    final detected = engine.ingest(
      CabinObservation(
        at: started.add(const Duration(milliseconds: 2100)),
        speedKph: 40,
        leftEyeOpen: 0.1,
        rightEyeOpen: 0.1,
      ),
    );
    expect(detected, hasLength(1));
    expect(detected.single.type, SafetyDetectionType.drowsiness);
    expect(
      engine.ingest(
        CabinObservation(
          at: started.add(const Duration(seconds: 3)),
          speedKph: 40,
          leftEyeOpen: 0.1,
          rightEyeOpen: 0.1,
        ),
      ),
      isEmpty,
    );
  });

  test('phone requires driving speed, duration and excludes fixed device', () {
    final engine = TemporalSafetyEngine();
    final started = DateTime(2026, 7, 27, 8);

    engine.ingest(
      CabinObservation(at: started, speedKph: 35, phoneConfidence: 0.9),
    );
    final detected = engine.ingest(
      CabinObservation(
        at: started.add(const Duration(milliseconds: 2100)),
        speedKph: 35,
        phoneConfidence: 0.9,
      ),
    );
    expect(detected.single.type, SafetyDetectionType.phoneUsage);

    final fixedEngine = TemporalSafetyEngine();
    fixedEngine.ingest(
      CabinObservation(
        at: started,
        speedKph: 35,
        phoneConfidence: 0.95,
        fixedDevice: true,
      ),
    );
    expect(
      fixedEngine.ingest(
        CabinObservation(
          at: started.add(const Duration(seconds: 3)),
          speedKph: 35,
          phoneConfidence: 0.95,
          fixedDevice: true,
        ),
      ),
      isEmpty,
    );
  });

  test('perclos catches repeated microsleeps', () {
    final engine = TemporalSafetyEngine();
    final started = DateTime(2026, 7, 27, 8);
    var detections = <SafetyDetection>[];
    for (var index = 0; index < 6; index++) {
      detections = engine.ingest(
        CabinObservation(
          at: started.add(Duration(milliseconds: index * 400)),
          speedKph: 45,
          leftEyeOpen: index.isEven ? 0.1 : 0.8,
          rightEyeOpen: index.isEven ? 0.1 : 0.8,
        ),
      );
    }
    expect(detections.single.type, SafetyDetectionType.drowsiness);
    expect(detections.single.reason, contains('PERCLOS'));
  });

  test('drowsiness rules can be disabled without disabling phone alerts', () {
    final engine = TemporalSafetyEngine(drowsinessEnabled: false);
    final started = DateTime(2026, 7, 27, 8);

    engine.ingest(
      CabinObservation(
        at: started,
        speedKph: 40,
        leftEyeOpen: 0.05,
        rightEyeOpen: 0.05,
        phoneConfidence: 0.9,
      ),
    );
    final detections = engine.ingest(
      CabinObservation(
        at: started.add(const Duration(milliseconds: 2100)),
        speedKph: 40,
        leftEyeOpen: 0.05,
        rightEyeOpen: 0.05,
        phoneConfidence: 0.9,
      ),
    );

    expect(detections, hasLength(1));
    expect(detections.single.type, SafetyDetectionType.phoneUsage);
  });
}
