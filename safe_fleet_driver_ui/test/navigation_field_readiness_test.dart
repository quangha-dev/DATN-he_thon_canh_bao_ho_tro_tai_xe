import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/geo.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/guidance_planner.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/maneuver.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/nav_route.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/navigation_engine.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/route_simulator.dart';

/// Kiểm thử sẵn sàng vận hành cho hệ thống dẫn đường.
///
/// Mỗi nhóm dưới đây là một tình huống có thật trên đường Hà Nội, phát lại qua
/// đúng engine mà GPS thật đi vào, với ngưỡng đạt/không đạt viết rõ trong phần
/// assert. Bộ này trả lời câu hỏi "hệ thống có chạy được ngoài thực tế không"
/// ở phần có thể trả lời được trên máy; những gì chỉ đường thật mới trả lời
/// được thì liệt kê ở cuối file.
///
/// Chạy riêng và xem số đo:
/// ```
/// flutter test test/navigation_field_readiness_test.dart
/// ```

// ---------------------------------------------------------------------------
// Dựng một chuyến giao hàng nội đô ~11,4 km với 12 lần chuyển hướng.
// ---------------------------------------------------------------------------

const _startLat = 21.0450;
const _startLng = 105.8850;
const _vertexSpacingMeters = 20.0;

class _Leg {
  const _Leg(this.bearing, this.meters, this.maneuver, this.road);

  final double bearing;
  final double meters;
  final SfManeuver maneuver;
  final String road;
}

/// Các chặng nối tiếp nhau; hướng là hướng đi CỦA chặng, maneuver là động tác
/// phải làm để VÀO chặng đó.
const _legs = <_Leg>[
  _Leg(90, 850, SfManeuver.depart, 'Nguyễn Văn Cừ'),
  _Leg(180, 1200, SfManeuver.right, 'Nguyễn Sơn'),
  _Leg(90, 400, SfManeuver.left, 'Ngọc Lâm'),
  _Leg(135, 2600, SfManeuver.slightRight, 'Cầu Chương Dương'),
  _Leg(180, 700, SfManeuver.right, 'Trần Nhật Duật'),
  _Leg(90, 300, SfManeuver.left, 'Hàng Đậu'),
  _Leg(180, 1500, SfManeuver.right, 'Phùng Hưng'),
  _Leg(90, 250, SfManeuver.left, 'Hàng Bông'),
  _Leg(180, 900, SfManeuver.right, 'Phố Huế'),
  _Leg(90, 600, SfManeuver.left, 'Đại Cồ Việt'),
  _Leg(180, 1800, SfManeuver.right, 'Giải Phóng'),
  _Leg(90, 300, SfManeuver.left, 'Ngõ 102 Trường Chinh'),
];

double _lngPerMeter(double latitude) =>
    1 / SfGeo.metersPerLongitudeDegree(latitude);
const _latPerMeter = 1 / SfGeo.metersPerLatitudeDegree;

LatLng _translate(LatLng from, double bearingDeg, double meters) {
  final radians = bearingDeg * math.pi / 180;
  return LatLng(
    from.latitude + math.cos(radians) * meters * _latPerMeter,
    from.longitude + math.sin(radians) * meters * _lngPerMeter(from.latitude),
  );
}

/// Tuyến dạng JSON giống hệt thứ backend trả về, kể cả `beginShapeIndex`.
Map<String, dynamic> _deliveryRouteJson({double scale = 1.0}) {
  var cursor = const LatLng(_startLat, _startLng);
  final geometry = <List<double>>[
    [cursor.longitude, cursor.latitude],
  ];
  final steps = <Map<String, dynamic>>[];

  for (final leg in _legs) {
    steps.add(<String, dynamic>{
      'instruction': leg.maneuver == SfManeuver.depart
          ? 'Bắt đầu đi trên ${leg.road}'
          : '${leg.maneuver.shortPhrase} vào ${leg.road}',
      'roadName': leg.road,
      'maneuver': _backendName(leg.maneuver),
      'beginShapeIndex': geometry.length - 1,
      'distanceMeters': leg.meters * scale,
      'durationSeconds': leg.meters * scale / 8.5,
      'lat': cursor.latitude,
      'lng': cursor.longitude,
    });
    final meters = leg.meters * scale;
    final vertices = math.max(1, (meters / _vertexSpacingMeters).ceil());
    for (var index = 1; index <= vertices; index++) {
      final point = _translate(cursor, leg.bearing, meters * index / vertices);
      geometry.add([point.longitude, point.latitude]);
    }
    cursor = _translate(cursor, leg.bearing, meters);
  }

  steps.add(<String, dynamic>{
    'instruction': 'Đã đến điểm đến',
    'roadName': '',
    'maneuver': 'ARRIVE',
    'beginShapeIndex': geometry.length - 1,
    'distanceMeters': 0,
    'durationSeconds': 0,
    'lat': cursor.latitude,
    'lng': cursor.longitude,
  });

  final total = _legs.fold<double>(0, (sum, leg) => sum + leg.meters) * scale;
  return <String, dynamic>{
    'routeIndex': 0,
    'label': 'Đề xuất ít rủi ro nhất',
    'provider': 'VALHALLA',
    'fallback': false,
    'safe': true,
    'distanceMeters': total,
    'durationSeconds': total / 8.5,
    'geometry': geometry,
    'steps': steps,
    'warnings': <String>[],
  };
}

String _backendName(SfManeuver maneuver) => switch (maneuver) {
  SfManeuver.depart => 'DEPART',
  SfManeuver.left => 'TURN_LEFT',
  SfManeuver.right => 'TURN_RIGHT',
  SfManeuver.slightRight => 'TURN_SLIGHT_RIGHT',
  SfManeuver.slightLeft => 'TURN_SLIGHT_LEFT',
  _ => 'CONTINUE',
};

NavRoute _route({double scale = 1.0, List<NavHazard> hazards = const []}) =>
    NavRoute.fromJson(_deliveryRouteJson(scale: scale), hazards: hazards)!;

// ---------------------------------------------------------------------------
// Sinh vệt GPS: nhiễu hai chiều trong đĩa bán kính cho trước, kèm mốc thật để
// đo được sai số bám tuyến.
// ---------------------------------------------------------------------------

class _Sample {
  const _Sample(this.fix, this.trueOffsetMeters);

  final NavFix fix;
  final double trueOffsetMeters;
}

List<_Sample> _drive(
  NavRoute route, {
  double speedMps = 9,
  double stepSeconds = 1,
  double noiseRadiusMeters = 8,
  double accuracyMeters = 8,
  double fromOffset = 0,
  double? toOffset,
  int seed = 11,
  DateTime? startAt,
}) {
  final random = math.Random(seed);
  final start = startAt ?? DateTime(2026, 3, 2, 7, 30);
  final end = math.min(toOffset ?? route.lengthMeters, route.lengthMeters);
  final samples = <_Sample>[];
  var offset = fromOffset;
  var elapsed = 0.0;

  while (offset <= end) {
    final truth = RouteSimulator.pointAt(route, offset);
    // Nhiễu đều trong đĩa: lệch cả dọc lẫn ngang, đúng kiểu máy thu thật.
    final angle = random.nextDouble() * 2 * math.pi;
    final radius = noiseRadiusMeters * math.sqrt(random.nextDouble());
    samples.add(
      _Sample(
        NavFix(
          position: LatLng(
            truth.latitude + math.cos(angle) * radius * _latPerMeter,
            truth.longitude +
                math.sin(angle) * radius * _lngPerMeter(truth.latitude),
          ),
          timestamp: start.add(
            Duration(milliseconds: (elapsed * 1000).round()),
          ),
          accuracyMeters: accuracyMeters,
          headingDeg: RouteSimulator.bearingAt(route, offset),
          speedMps: speedMps,
        ),
        offset,
      ),
    );
    offset += speedMps * stepSeconds;
    elapsed += stepSeconds;
  }
  return samples;
}

double _percentile(List<double> values, double fraction) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final index = ((sorted.length - 1) * fraction).round();
  return sorted[index];
}

/// Chỉ số các bước thực sự bắt tài xế chuyển hướng.
List<int> _turnStepIndexes(NavRoute route) => [
  for (final step in route.steps)
    if (step.maneuver.isDirectionChange && !step.isArrival) step.index,
];

void main() {
  group('TH-1 · Chuyến nội đô bình thường', () {
    test('bám tuyến chính xác, đọc đủ chỉ dẫn, tới nơi', () {
      final route = _route();
      final engine = NavigationEngine(
        route: route,
        destination: route.geometry.last,
      );
      final planner = GuidancePlanner(destinationName: 'Kho Trường Chinh');

      final offsetErrors = <double>[];
      final cues = <String>[];
      var falseOffRoute = 0;
      NavState? last;

      for (final sample in _drive(route)) {
        final state = engine.update(sample.fix);
        cues.addAll(planner.plan(state).map((cue) => cue.id));
        offsetErrors.add(
          (state.travelledMeters - sample.trueOffsetMeters).abs(),
        );
        if (state.offRoute) falseOffRoute++;
        last = state;
      }

      final p95 = _percentile(offsetErrors, 0.95);
      final worst = offsetErrors.reduce(math.max);
      // ignore: avoid_print
      print(
        'TH-1  tuyến ${(route.lengthMeters / 1000).toStringAsFixed(1)} km · '
        'sai số bám tuyến P95 ${p95.toStringAsFixed(1)} m · '
        'lớn nhất ${worst.toStringAsFixed(1)} m',
      );

      // Bám tuyến phải đủ chính xác để "còn bao xa tới khúc rẽ" dùng được.
      expect(p95, lessThan(15));
      expect(worst, lessThan(40));

      // Không được có lệch tuyến giả trên một chuyến đi đúng đường.
      expect(falseOffRoute, 0);

      // Mỗi khúc rẽ phải được đọc đúng một lần, đúng thứ tự.
      for (final index in _turnStepIndexes(route)) {
        expect(
          cues.where((id) => id == 'step:$index:execute'),
          hasLength(1),
          reason: 'khúc rẽ $index phải được đọc đúng một lần',
        );
      }
      final executeOrder = [
        for (final id in cues)
          if (id.endsWith(':execute')) int.parse(id.split(':')[1]),
      ];
      expect(
        executeOrder,
        orderedEquals(_turnStepIndexes(route)),
        reason: 'chỉ dẫn phải đến đúng thứ tự dọc tuyến',
      );

      expect(last!.arrived, isTrue);
      expect(cues, contains('arrived'));
    });
  });

  group('TH-2 · GPS kém trong phố cổ', () {
    test('sai số 35 m không tạo lệch tuyến giả và không bỏ sót chỉ dẫn', () {
      final route = _route();
      final engine = NavigationEngine(
        route: route,
        destination: route.geometry.last,
      );
      final planner = GuidancePlanner();

      final cues = <String>[];
      var offRouteFixes = 0;
      var rerouteDemanded = 0;
      NavState? last;

      for (final sample in _drive(
        route,
        noiseRadiusMeters: 28,
        accuracyMeters: 35,
        seed: 23,
      )) {
        final state = engine.update(sample.fix);
        cues.addAll(planner.plan(state).map((cue) => cue.id));
        if (state.offRoute) offRouteFixes++;
        if (state.rerouteRequired) rerouteDemanded++;
        last = state;
      }

      // ignore: avoid_print
      print(
        'TH-2  nhiễu 28 m · số nhịp bị coi là lệch tuyến $offRouteFixes · '
        'số lần đòi tính lại tuyến $rerouteDemanded',
      );

      expect(
        rerouteDemanded,
        0,
        reason: 'GPS kém không được làm hệ thống tự đổi tuyến',
      );
      for (final index in _turnStepIndexes(route)) {
        expect(cues, contains('step:$index:execute'));
      }
      expect(last!.arrived, isTrue);
    });

    test('nhịp GPS quá tệ bị bỏ qua thay vì tin nhầm', () {
      final route = _route();
      final engine = NavigationEngine(
        route: route,
        destination: route.geometry.last,
      );

      final state = engine.update(
        NavFix(
          position: _translate(route.geometry[20], 0, 500),
          timestamp: DateTime(2026, 3, 2, 7, 30),
          accuracyMeters: 180,
          speedMps: 9,
        ),
      );

      expect(state.gpsUsable, isFalse);
      expect(state.offRoute, isFalse);
      expect(state.rerouteRequired, isFalse);
    });
  });

  group('TH-3 · Mất tín hiệu khi qua cầu và hầm chui', () {
    test('45 giây không có nhịp nào, bắt lại đúng vị trí, không đổi tuyến', () {
      final route = _route();
      final engine = NavigationEngine(
        route: route,
        destination: route.geometry.last,
      );
      final planner = GuidancePlanner();

      final before = _drive(route, toOffset: 2400);
      for (final sample in before) {
        planner.plan(engine.update(sample.fix));
      }
      final beforeGap = engine.state!.travelledMeters;

      // Xe chạy tiếp 600 m trong lúc mất sóng rồi mới có nhịp trở lại.
      final resumeAt = 3000.0;
      final resumeTime = before.last.fix.timestamp.add(
        const Duration(seconds: 45),
      );
      final after = _drive(
        route,
        fromOffset: resumeAt,
        toOffset: resumeAt + 400,
        startAt: resumeTime,
        seed: 31,
      );

      var rerouteDemanded = 0;
      NavState? state;
      for (final sample in after) {
        state = engine.update(sample.fix);
        if (state.rerouteRequired) rerouteDemanded++;
      }

      // ignore: avoid_print
      print(
        'TH-3  trước khi mất sóng ${beforeGap.toStringAsFixed(0)} m · '
        'bắt lại tại ${state!.travelledMeters.toStringAsFixed(0)} m '
        '(thật ${(resumeAt + 400).toStringAsFixed(0)} m)',
      );

      expect(
        (state.travelledMeters - (resumeAt + 400)).abs(),
        lessThan(60),
        reason: 'phải bắt lại đúng đoạn đang đi sau khi có sóng',
      );
      expect(
        rerouteDemanded,
        0,
        reason: 'mất sóng rồi có lại không phải là đi sai đường',
      );
      expect(state.offRoute, isFalse);
    });
  });

  group('TH-4 · Tài xế rẽ nhầm', () {
    test('đòi tính lại tuyến đủ nhanh nhưng không hấp tấp', () {
      final route = _route();
      final engine = NavigationEngine(
        route: route,
        destination: route.geometry.last,
      );

      for (final sample in _drive(route, toOffset: 1600)) {
        engine.update(sample.fix);
      }
      final leftAt = engine.state!.travelledMeters;
      final departure = RouteSimulator.pointAt(route, leftAt);
      final wrongBearing =
          (RouteSimulator.bearingAt(route, leftAt) + 90) % 360;

      Duration? demandedAfter;
      double? demandedDistance;
      final start = DateTime(2026, 3, 2, 7, 45);

      for (var second = 1; second <= 40; second++) {
        final travelled = 9.0 * second;
        final state = engine.update(
          NavFix(
            position: _translate(departure, wrongBearing, travelled),
            timestamp: start.add(Duration(seconds: second)),
            accuracyMeters: 8,
            headingDeg: wrongBearing,
            speedMps: 9,
          ),
        );
        if (state.rerouteRequired) {
          demandedAfter = Duration(seconds: second);
          demandedDistance = travelled;
          break;
        }
      }

      // ignore: avoid_print
      print(
        'TH-4  đòi tính lại sau ${demandedAfter?.inSeconds} giây · '
        '${demandedDistance?.toStringAsFixed(0)} m kể từ lúc rời tuyến',
      );

      expect(demandedAfter, isNotNull, reason: 'phải phát hiện được rẽ nhầm');
      // Không sớm hơn ngưỡng xác nhận: tránh đổi tuyến vì một nhịp GPS xấu.
      expect(demandedAfter!.inSeconds, greaterThanOrEqualTo(10));
      // Không muộn tới mức tài xế đã đi lạc cả cây số.
      expect(demandedAfter.inSeconds, lessThanOrEqualTo(25));
      expect(demandedDistance, lessThan(300));
    });

    test('quay lại đúng tuyến thì thôi báo lệch, không cần tính lại', () {
      final route = _route();
      final engine = NavigationEngine(
        route: route,
        destination: route.geometry.last,
      );

      for (final sample in _drive(route, toOffset: 1600)) {
        engine.update(sample.fix);
      }
      final departure = RouteSimulator.pointAt(route, 1600);
      final side = (RouteSimulator.bearingAt(route, 1600) + 90) % 360;
      final start = DateTime(2026, 3, 2, 7, 45);

      // Lệch ra 60 m rồi lập tức tạt lại vào tuyến.
      for (var second = 1; second <= 6; second++) {
        engine.update(
          NavFix(
            position: _translate(departure, side, 10.0 * second),
            timestamp: start.add(Duration(seconds: second)),
            accuracyMeters: 8,
            speedMps: 9,
          ),
        );
      }
      expect(engine.state!.offRoute, isTrue);

      NavState? state;
      for (final sample in _drive(
        route,
        fromOffset: 1620,
        toOffset: 1800,
        startAt: start.add(const Duration(seconds: 8)),
      )) {
        state = engine.update(sample.fix);
      }

      expect(state!.offRoute, isFalse);
      expect(state.rerouteRequired, isFalse);
    });
  });

  group('TH-5 · Tài xế báo ngập giữa đường', () {
    test('cảnh báo trước khi tới, tính lại tuyến, không quay về điểm đầu', () {
      // Đoạn ngập nằm trên tuyến, cách điểm xuất phát 5,2 km.
      final base = _route();
      final hazard = NavHazard(
        id: 77,
        hazardType: 'FLOOD',
        severity: 'BLOCKED',
        hardClosure: true,
        geometry: [RouteSimulator.pointAt(base, 5200)],
        radiusMeters: 70,
        address: 'Trần Nhật Duật',
      );
      final route = _route(hazards: [hazard]);
      final engine = NavigationEngine(
        route: route,
        destination: route.geometry.last,
      );
      final planner = GuidancePlanner();

      expect(
        route.hazardsOnRouteCount,
        1,
        reason: 'đoạn ngập phải được nhận ra là nằm trên tuyến',
      );

      final cues = <GuidanceCue>[];
      double? warnedAt;
      for (final sample in _drive(route, toOffset: 5100)) {
        final state = engine.update(sample.fix);
        final planned = planner.plan(state);
        if (warnedAt == null &&
            planned.any((cue) => cue.id.startsWith('hazard:'))) {
          warnedAt = state.hazardDistanceMeters;
        }
        cues.addAll(planned);
      }

      final hazardCues = cues.where((cue) => cue.id.startsWith('hazard:'));
      // ignore: avoid_print
      print(
        'TH-5  cảnh báo lần đầu khi còn ${warnedAt?.toStringAsFixed(0)} m · '
        'tổng ${hazardCues.length} cảnh báo',
      );

      expect(warnedAt, isNotNull);
      expect(
        warnedAt!,
        greaterThan(200),
        reason: 'phải cảnh báo đủ sớm để còn kịp xử lý',
      );
      expect(
        hazardCues.every((cue) => cue.priority == GuidancePriority.urgent),
        isTrue,
      );

      // Backend trả tuyến mới né đoạn ngập; engine phải tiếp tục từ chỗ đang
      // đứng chứ không đưa tài xế về điểm xuất phát.
      final positionNow = engine.state!.snapped;
      final replacement = _route();
      engine.replaceRoute(replacement, at: positionNow);
      planner.onRouteReplaced();

      final afterReroute = engine.update(
        NavFix(
          position: positionNow,
          timestamp: DateTime(2026, 3, 2, 8, 10),
          accuracyMeters: 8,
          speedMps: 9,
        ),
      );

      expect(afterReroute.travelledMeters, closeTo(5100, 120));
      expect(afterReroute.offRoute, isFalse);
      expect(afterReroute.arrived, isFalse);
    });

    test('điểm ngập ngoài tuyến không làm phiền tài xế', () {
      final base = _route();
      final faraway = NavHazard(
        id: 78,
        hazardType: 'FLOOD',
        severity: 'BLOCKED',
        hardClosure: true,
        // Cách tuyến 1,5 km.
        geometry: [_translate(RouteSimulator.pointAt(base, 5200), 270, 1500)],
        radiusMeters: 70,
      );
      final route = _route(hazards: [faraway]);

      expect(route.hazardsOnRouteCount, 0);

      final engine = NavigationEngine(
        route: route,
        destination: route.geometry.last,
      );
      final planner = GuidancePlanner();
      final cues = <String>[];
      for (final sample in _drive(route, toOffset: 6000)) {
        cues.addAll(planner.plan(engine.update(sample.fix)).map((c) => c.id));
      }

      expect(cues.where((id) => id.startsWith('hazard:')), isEmpty);
    });
  });

  group('TH-6 · Xe dừng lâu', () {
    test('kẹt xe 12 phút không sinh chỉ dẫn lạ và không đổi tuyến', () {
      final route = _route();
      final engine = NavigationEngine(
        route: route,
        destination: route.geometry.last,
      );
      final planner = GuidancePlanner();

      for (final sample in _drive(route, toOffset: 3000)) {
        planner.plan(engine.update(sample.fix));
      }
      final stopped = RouteSimulator.pointAt(route, 3000);
      final start = DateTime(2026, 3, 2, 8);

      final cues = <String>[];
      var rerouteDemanded = 0;
      NavState? state;
      final random = math.Random(5);
      for (var second = 0; second < 720; second++) {
        final angle = random.nextDouble() * 2 * math.pi;
        final radius = 12 * math.sqrt(random.nextDouble());
        state = engine.update(
          NavFix(
            position: LatLng(
              stopped.latitude + math.cos(angle) * radius * _latPerMeter,
              stopped.longitude +
                  math.sin(angle) * radius * _lngPerMeter(stopped.latitude),
            ),
            timestamp: start.add(Duration(seconds: second)),
            accuracyMeters: 14,
            speedMps: 0,
          ),
        );
        cues.addAll(planner.plan(state).map((cue) => cue.id));
        if (state.rerouteRequired) rerouteDemanded++;
      }

      // ignore: avoid_print
      print(
        'TH-6  đứng yên 12 phút · số lần đòi tính lại $rerouteDemanded · '
        'ETA còn ${state!.remainingDuration.inMinutes} phút',
      );

      expect(rerouteDemanded, 0);
      expect(state.arrived, isFalse);
      // Chặng đang đi dài 2,6 km nên chỉ dẫn kế tiếp có thể được nhắc,
      // nhưng không được lặp lại trong lúc xe không nhúc nhích.
      expect(cues.toSet(), hasLength(cues.length));
      expect(state.remainingDuration.inMinutes, greaterThan(0));
    });
  });

  group('TH-7 · Mở lại ứng dụng giữa hành trình', () {
    test('nhịp GPS đầu tiên ở 60% quãng đường được định vị đúng', () {
      final route = _route();
      final engine = NavigationEngine(
        route: route,
        destination: route.geometry.last,
      );
      final resumeAt = route.lengthMeters * 0.6;

      final state = engine.update(
        NavFix(
          position: RouteSimulator.pointAt(route, resumeAt),
          timestamp: DateTime(2026, 3, 2, 8, 20),
          accuracyMeters: 10,
          headingDeg: RouteSimulator.bearingAt(route, resumeAt),
          speedMps: 9,
        ),
      );

      // ignore: avoid_print
      print(
        'TH-7  mở lại app · định vị ${state.travelledMeters.toStringAsFixed(0)} m '
        '(thật ${resumeAt.toStringAsFixed(0)} m)',
      );

      expect((state.travelledMeters - resumeAt).abs(), lessThan(30));
      expect(state.offRoute, isFalse);
      expect(state.upcomingStep, isNotNull);
    });
  });

  group('TH-8 · Ngân sách hiệu năng trên máy tài xế', () {
    test('mỗi nhịp GPS xử lý dưới 1 ms và không đắt thêm theo chiều dài tuyến', () {
      double costPerFixMicros(NavRoute route) {
        final engine = NavigationEngine(
          route: route,
          destination: route.geometry.last,
        );
        final samples = _drive(route, speedMps: 12);
        final watch = Stopwatch()..start();
        for (final sample in samples) {
          engine.update(sample.fix);
        }
        watch.stop();
        return watch.elapsedMicroseconds / samples.length;
      }

      final short = _route(scale: 0.2); // ~2,3 km
      final long = _route(scale: 2.0); // ~22,8 km

      // Một vòng làm nóng để JIT không bị tính vào phép đo.
      costPerFixMicros(short);

      final shortCost = costPerFixMicros(short);
      final longCost = costPerFixMicros(long);

      // ignore: avoid_print
      print(
        'TH-8  ${shortCost.toStringAsFixed(0)} µs/nhịp trên tuyến 2,3 km · '
        '${longCost.toStringAsFixed(0)} µs/nhịp trên tuyến 22,8 km · '
        'tỉ lệ ${(longCost / shortCost).toStringAsFixed(2)}×',
      );

      expect(
        longCost,
        lessThan(1000),
        reason: 'một nhịp GPS phải xong trong dưới 1 ms',
      );
      // Điểm mấu chốt của cửa sổ trượt: tuyến dài gấp 10 lần không được đắt
      // hơn nhiều lần. Tìm điểm gần nhất trên toàn polyline sẽ trượt bài này.
      expect(
        longCost / shortCost,
        lessThan(3.0),
        reason: 'chi phí phải gần như không phụ thuộc chiều dài tuyến',
      );
    });
  });

  group('TH-9 · Dữ liệu tuyến hỏng không làm sập dẫn đường', () {
    test('bỏ qua phương án không có hình học, giữ phương án dùng được', () {
      final session = NavSession.fromJson({
        'sessionId': 'session-hong',
        'selectedRouteIndex': 0,
        'routes': [
          {'routeIndex': 0, 'geometry': <dynamic>[]},
          {..._deliveryRouteJson(), 'routeIndex': 1},
        ],
      });

      expect(session.isEmpty, isFalse);
      expect(session.routes, hasLength(1));
    });

    test('tuyến không có bước chỉ dẫn vẫn chạy được, chỉ mất câu đọc', () {
      final json = _deliveryRouteJson()..remove('steps');
      final route = NavRoute.fromJson(json)!;
      final engine = NavigationEngine(
        route: route,
        destination: route.geometry.last,
      );

      NavState? state;
      for (final sample in _drive(route, speedMps: 14)) {
        state = engine.update(sample.fix);
      }

      expect(state!.arrived, isTrue);
      expect(state.upcomingStep, isNull);
    });

    test('mốc bước sai vẫn được ép về thứ tự tăng dần', () {
      final json = _deliveryRouteJson();
      final steps = (json['steps'] as List).cast<Map<String, dynamic>>();
      // Nhà cung cấp thỉnh thoảng trả mốc lùi lại ở ranh giới chặng.
      steps[3]['beginShapeIndex'] = 1;
      final route = NavRoute.fromJson(json)!;

      for (var index = 1; index < route.steps.length; index++) {
        expect(
          route.steps[index].startOffsetMeters,
          greaterThanOrEqualTo(route.steps[index - 1].startOffsetMeters),
        );
      }
    });
  });
}
