import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/geo.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/guidance_planner.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/maneuver.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/nav_route.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/navigation_engine.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/route_simulator.dart';

/// Ha Noi-ish anchor so the longitude scaling is realistic.
const _originLat = 21.0285;
const _originLng = 105.8542;

double _lngPerMeter(double latitude) => 1 / SfGeo.metersPerLongitudeDegree(latitude);
const _latPerMeter = 1 / SfGeo.metersPerLatitudeDegree;

/// Densifies a leg into ~25 m vertices, the way a real road graph returns it.
List<List<double>> _leg(
  LatLng from,
  double bearingDeg,
  double meters, {
  double spacing = 25,
}) {
  final points = <List<double>>[];
  final radians = bearingDeg * math.pi / 180;
  final steps = math.max(1, (meters / spacing).ceil());
  for (var index = 1; index <= steps; index++) {
    final travelled = meters * index / steps;
    final lat = from.latitude + math.cos(radians) * travelled * _latPerMeter;
    final lng =
        from.longitude + math.sin(radians) * travelled * _lngPerMeter(from.latitude);
    points.add([lng, lat]);
  }
  return points;
}

LatLng _last(List<List<double>> points) =>
    LatLng(points.last[1], points.last[0]);

/// An L-shaped route: 1200 m east, right turn, 800 m south.
Map<String, dynamic> _lRouteJson() {
  final start = const LatLng(_originLat, _originLng);
  final geometry = <List<double>>[
    [start.longitude, start.latitude],
  ];
  final east = _leg(start, 90, 1200);
  geometry.addAll(east);
  final corner = _last(east);
  final cornerIndex = geometry.length - 1;
  geometry.addAll(_leg(corner, 180, 800));

  return <String, dynamic>{
    'routeIndex': 0,
    'label': 'Đề xuất ít rủi ro nhất',
    'provider': 'VALHALLA',
    'fallback': false,
    'safe': true,
    'blocked': false,
    'distanceMeters': 2000,
    'durationSeconds': 240,
    'geometry': geometry,
    'warnings': <String>[],
    'steps': <Map<String, dynamic>>[
      {
        'instruction': 'Bắt đầu đi trên Đường Láng',
        'roadName': 'Đường Láng',
        'maneuver': 'DEPART',
        'beginShapeIndex': 0,
        'distanceMeters': 1200,
        'durationSeconds': 144,
        'lat': start.latitude,
        'lng': start.longitude,
      },
      {
        'instruction': 'Rẽ phải vào Phố Huế',
        'roadName': 'Phố Huế',
        'maneuver': 'TURN_RIGHT',
        'beginShapeIndex': cornerIndex,
        'distanceMeters': 800,
        'durationSeconds': 96,
        'lat': corner.latitude,
        'lng': corner.longitude,
      },
      {
        'instruction': 'Đã đến điểm đến',
        'roadName': '',
        'maneuver': 'ARRIVE',
        'beginShapeIndex': geometry.length - 1,
        'distanceMeters': 0,
        'durationSeconds': 0,
        'lat': geometry.last[1],
        'lng': geometry.last[0],
      },
    ],
  };
}

/// Out and back: 620 m east, then the same street 12 m to the north heading
/// west. A global nearest-point matcher jumps between the two legs here.
Map<String, dynamic> _doubleBackRouteJson() {
  final start = const LatLng(_originLat, _originLng);
  final geometry = <List<double>>[
    [start.longitude, start.latitude],
  ];
  final out = _leg(start, 90, 620);
  geometry.addAll(out);
  final turn = _last(out);
  final shift = _leg(turn, 0, 12, spacing: 6);
  geometry.addAll(shift);
  geometry.addAll(_leg(_last(shift), 270, 620));

  return <String, dynamic>{
    'routeIndex': 0,
    'provider': 'VALHALLA',
    'distanceMeters': 1252,
    'durationSeconds': 150,
    'geometry': geometry,
    'steps': <Map<String, dynamic>>[
      {
        'instruction': 'Bắt đầu hành trình',
        'maneuver': 'DEPART',
        'beginShapeIndex': 0,
        'distanceMeters': 620,
      },
      {
        'instruction': 'Quay đầu xe',
        'maneuver': 'UTURN_LEFT',
        'beginShapeIndex': out.length,
        'distanceMeters': 632,
      },
      {
        'instruction': 'Đã đến điểm đến',
        'maneuver': 'ARRIVE',
        'beginShapeIndex': geometry.length - 1,
        'distanceMeters': 0,
      },
    ],
  };
}

NavRoute _route(Map<String, dynamic> json, {List<NavHazard> hazards = const []}) =>
    NavRoute.fromJson(json, hazards: hazards)!;

LatLng _destinationOf(NavRoute route) => route.geometry.last;

void main() {
  group('route model', () {
    test('anchors step offsets to the polyline, not to provider step lengths', () {
      final route = _route(_lRouteJson());

      expect(route.steps, hasLength(3));
      expect(route.steps.first.startOffsetMeters, closeTo(0, 0.1));
      // The turn is 1200 m along the road; the offset must agree with the
      // geometry the matcher measures against, within a vertex spacing.
      expect(route.steps[1].startOffsetMeters, closeTo(1200, 30));
      expect(route.steps[1].maneuver, SfManeuver.right);
      expect(route.steps.last.maneuver, SfManeuver.arrive);
      expect(route.lengthMeters, closeTo(2000, 40));
    });

    test('rescales legacy steps that carry no shape index', () {
      final json = _lRouteJson();
      for (final step in (json['steps'] as List).cast<Map<String, dynamic>>()) {
        step.remove('beginShapeIndex');
      }
      final route = _route(json);

      expect(route.steps[1].startOffsetMeters, closeTo(1200, 40));
      expect(
        route.steps.last.endOffsetMeters,
        closeTo(route.lengthMeters, 1),
      );
    });

    test('falls back to the coarse modifier when the maneuver is unknown', () {
      expect(SfManeuver.parse(null, modifier: 'left'), SfManeuver.left);
      expect(SfManeuver.parse('10', modifier: 'right'), SfManeuver.right);
      expect(SfManeuver.parse('TURN_SHARP_LEFT'), SfManeuver.sharpLeft);
      expect(SfManeuver.parse(null), SfManeuver.straightOn);
    });
  });

  group('map matching', () {
    test('keeps progress monotonic where the route doubles back on itself', () {
      final route = _route(_doubleBackRouteJson());
      final engine = NavigationEngine(
        route: route,
        destination: _destinationOf(route),
      );

      // Bias every fix 8 m north — towards the return leg, which sits 12 m away.
      final fixes = RouteSimulator.drive(
        route,
        speedMps: 9,
        toOffset: 600,
      ).map((fix) {
        return NavFix(
          position: LatLng(
            fix.position.latitude + 8 * _latPerMeter,
            fix.position.longitude,
          ),
          timestamp: fix.timestamp,
          accuracyMeters: fix.accuracyMeters,
          headingDeg: fix.headingDeg,
          speedMps: fix.speedMps,
        );
      }).toList();

      var previous = -1.0;
      for (final fix in fixes) {
        final state = engine.update(fix);
        expect(
          state.travelledMeters,
          greaterThanOrEqualTo(previous - 1),
          reason: 'progress jumped backwards to the other carriageway',
        );
        previous = state.travelledMeters;
      }
      // Still on the outbound leg, not teleported onto the return leg.
      expect(previous, closeTo(600, 60));
      expect(previous, lessThan(700));
    });

    test('lateral GPS noise never fakes a detour', () {
      final route = _route(_lRouteJson());
      final engine = NavigationEngine(
        route: route,
        destination: _destinationOf(route),
      );

      final fixes = RouteSimulator.drive(
        route,
        speedMps: 11,
        lateralNoiseMeters: 22,
        accuracyMeters: 12,
      );

      for (final fix in fixes) {
        final state = engine.update(fix);
        expect(state.rerouteRequired, isFalse);
        expect(state.offRoute, isFalse);
      }
    });
  });

  group('off-route confirmation', () {
    test('confirms a wrong turn only after fixes, time and ground covered', () {
      final route = _route(_lRouteJson());
      final engine = NavigationEngine(
        route: route,
        destination: _destinationOf(route),
      );

      for (final fix in RouteSimulator.drive(route, speedMps: 11, toOffset: 400)) {
        engine.update(fix);
      }
      final leftRouteAt = engine.state!.travelledMeters;

      final states = RouteSimulator.divert(
        route,
        fromOffset: leftRouteAt,
        distanceMeters: 300,
        speedMps: 11,
        startAt: DateTime(2026, 1, 1, 8, 5),
      ).map(engine.update).toList();

      expect(
        states.take(3).any((state) => state.rerouteRequired),
        isFalse,
        reason: 'a reroute must never fire on the first couple of bad fixes',
      );
      expect(states.any((state) => state.offRoute), isTrue);
      expect(states.last.rerouteRequired, isTrue);
      expect(states.last.offRouteFor.inSeconds, greaterThanOrEqualTo(10));
    });

    test('a parked vehicle with drifting GPS is never rerouted', () {
      final route = _route(_lRouteJson());
      final engine = NavigationEngine(
        route: route,
        destination: _destinationOf(route),
      );
      final parked = LatLng(
        route.geometry[10].latitude + 60 * _latPerMeter,
        route.geometry[10].longitude,
      );

      var rerouted = false;
      for (var second = 0; second < 120; second++) {
        final state = engine.update(
          NavFix(
            position: LatLng(
              parked.latitude + (second.isEven ? 2 : -2) * _latPerMeter,
              parked.longitude,
            ),
            timestamp: DateTime(2026, 1, 1, 8).add(Duration(seconds: second)),
            accuracyMeters: 10,
            speedMps: 0,
          ),
        );
        rerouted = rerouted || state.rerouteRequired;
      }

      expect(rerouted, isFalse);
    });

    test('ignores fixes too inaccurate to trust', () {
      final route = _route(_lRouteJson());
      final engine = NavigationEngine(
        route: route,
        destination: _destinationOf(route),
      );

      final state = engine.update(
        NavFix(
          position: LatLng(
            _originLat + 400 * _latPerMeter,
            _originLng,
          ),
          timestamp: DateTime(2026, 1, 1, 8),
          accuracyMeters: 180,
          speedMps: 10,
        ),
      );

      expect(state.gpsUsable, isFalse);
      expect(state.offRoute, isFalse);
      expect(state.rerouteRequired, isFalse);
    });
  });

  group('voice guidance', () {
    test('announces every turn once, in prepare/confirm/execute order', () {
      final route = _route(_lRouteJson());
      final engine = NavigationEngine(
        route: route,
        destination: _destinationOf(route),
      );
      final planner = GuidancePlanner(destinationName: 'Kho Gia Lâm');

      final spoken = <GuidanceCue>[];
      for (final fix in RouteSimulator.drive(route, speedMps: 11)) {
        spoken.addAll(planner.plan(engine.update(fix)));
      }

      final ids = spoken.map((cue) => cue.id).toList();
      expect(ids, contains('step:1:prepare'));
      expect(ids, contains('step:1:confirm'));
      expect(ids, contains('step:1:execute'));
      expect(
        ids.indexOf('step:1:prepare'),
        lessThan(ids.indexOf('step:1:confirm')),
      );
      expect(
        ids.indexOf('step:1:confirm'),
        lessThan(ids.indexOf('step:1:execute')),
      );
      // Nothing is ever said twice.
      expect(ids.toSet(), hasLength(ids.length));

      final prepare = spoken.firstWhere((cue) => cue.id == 'step:1:prepare');
      expect(prepare.text, startsWith('Sau '));
      expect(prepare.text, contains('mét'));
      expect(prepare.text, contains('Phố Huế'));

      final execute = spoken.firstWhere((cue) => cue.id == 'step:1:execute');
      expect(execute.text, 'Rẽ phải');

      expect(ids, contains('arrived'));
      expect(
        spoken.firstWhere((cue) => cue.id == 'arrived').text,
        'Bạn đã đến Kho Gia Lâm',
      );
    });

    test('skips the early heads-up when the leg is too short for it', () {
      final json = _lRouteJson();
      // Pull the turn in to 150 m from the start.
      final steps = (json['steps'] as List).cast<Map<String, dynamic>>();
      steps[1]['beginShapeIndex'] = 6;
      final route = _route(json);
      final engine = NavigationEngine(
        route: route,
        destination: _destinationOf(route),
      );
      final planner = GuidancePlanner();

      final ids = <String>[];
      for (final fix in RouteSimulator.drive(route, speedMps: 11, toOffset: 400)) {
        ids.addAll(planner.plan(engine.update(fix)).map((cue) => cue.id));
      }

      expect(ids, isNot(contains('step:1:prepare')));
      expect(ids, contains('step:1:execute'));
    });

    test('stays quiet about the next turn while off route', () {
      final route = _route(_lRouteJson());
      final engine = NavigationEngine(
        route: route,
        destination: _destinationOf(route),
      );
      final planner = GuidancePlanner();

      for (final fix in RouteSimulator.drive(route, speedMps: 11, toOffset: 300)) {
        planner.plan(engine.update(fix));
      }

      final cues = <GuidanceCue>[];
      for (final fix in RouteSimulator.divert(
        route,
        fromOffset: 300,
        distanceMeters: 300,
        speedMps: 11,
        startAt: DateTime(2026, 1, 1, 8, 5),
      )) {
        cues.addAll(planner.plan(engine.update(fix)));
      }

      expect(cues.map((cue) => cue.id), contains('offroute'));
      expect(
        cues.where((cue) => cue.id.startsWith('step:')),
        isEmpty,
        reason: 'the next turn is on a road the driver already left',
      );
    });

    test('warns about a flooded stretch ahead, far out and again close in', () {
      final json = _lRouteJson();
      final route = _route(json);
      // A closure sitting on the route 900 m in.
      final onRoute = RouteSimulator.pointAt(route, 900);
      final hazard = NavHazard(
        id: 42,
        hazardType: 'FLOOD',
        severity: 'BLOCKED',
        hardClosure: true,
        geometry: [onRoute],
        radiusMeters: 60,
        address: 'Ngã tư Sở',
      );
      final hazardRoute = _route(json, hazards: [hazard]);
      final engine = NavigationEngine(
        route: hazardRoute,
        destination: _destinationOf(hazardRoute),
      );
      final planner = GuidancePlanner();

      expect(hazardRoute.hazardsOnRouteCount, 1);

      final cues = <GuidanceCue>[];
      for (final fix in RouteSimulator.drive(hazardRoute, speedMps: 11, toOffset: 880)) {
        cues.addAll(planner.plan(engine.update(fix)));
      }

      final hazardCues = cues.where((cue) => cue.id.startsWith('hazard:')).toList();
      expect(hazardCues.map((cue) => cue.id), contains('hazard:42:far'));
      expect(hazardCues.map((cue) => cue.id), contains('hazard:42:near'));
      expect(
        hazardCues.every((cue) => cue.priority == GuidancePriority.urgent),
        isTrue,
      );
      expect(
        hazardCues.firstWhere((cue) => cue.id == 'hazard:42:near').text,
        contains('bị chặn'),
      );
    });
  });

  group('progress and eta', () {
    test('reports distance to the next turn, not to the destination', () {
      final route = _route(_lRouteJson());
      final engine = NavigationEngine(
        route: route,
        destination: _destinationOf(route),
      );

      final state = engine.update(
        RouteSimulator.drive(route, speedMps: 11, toOffset: 700).last,
      );

      expect(state.upcomingStep!.maneuver, SfManeuver.right);
      expect(state.distanceToManeuverMeters, closeTo(500, 60));
      expect(state.remainingMeters, closeTo(1300, 60));
      expect(state.currentRoadName, 'Đường Láng');
    });

    test('eta tightens when the vehicle runs faster than the plan', () {
      final route = _route(_lRouteJson());
      final slow = NavigationEngine(route: route, destination: _destinationOf(route));
      final fast = NavigationEngine(route: route, destination: _destinationOf(route));

      NavState? slowState;
      for (final fix in RouteSimulator.drive(route, speedMps: 5, toOffset: 600)) {
        slowState = slow.update(fix);
      }
      NavState? fastState;
      for (final fix in RouteSimulator.drive(route, speedMps: 20, toOffset: 600)) {
        fastState = fast.update(fix);
      }

      expect(
        fastState!.remainingDuration,
        lessThan(slowState!.remainingDuration),
      );
    });

    test('arrival is declared once the vehicle reaches the destination', () {
      final route = _route(_lRouteJson());
      final engine = NavigationEngine(
        route: route,
        destination: _destinationOf(route),
      );

      NavState? last;
      for (final fix in RouteSimulator.drive(route, speedMps: 11)) {
        last = engine.update(fix);
      }

      expect(last!.arrived, isTrue);
      expect(last.phase, NavPhase.arrived);
      expect(last.remainingMeters, lessThan(30));
    });

    test('a reroute keeps the driver where they are, not back at the origin', () {
      final route = _route(_lRouteJson());
      final engine = NavigationEngine(
        route: route,
        destination: _destinationOf(route),
      );
      for (final fix in RouteSimulator.drive(route, speedMps: 11, toOffset: 800)) {
        engine.update(fix);
      }

      final replacement = _route(_lRouteJson());
      engine.replaceRoute(replacement, at: RouteSimulator.pointAt(replacement, 800));
      final state = engine.update(
        NavFix(
          position: RouteSimulator.pointAt(replacement, 810),
          timestamp: DateTime(2026, 1, 1, 8, 10),
          accuracyMeters: 8,
          speedMps: 11,
        ),
      );

      expect(state.travelledMeters, closeTo(810, 40));
      expect(state.offRoute, isFalse);
    });
  });

  group('formatting', () {
    test('reads distances the way a driver expects', () {
      expect(formatDistance(42), '40 m');
      expect(formatDistance(230), '230 m');
      expect(formatDistance(1450), '1,5 km');
      // Ngưỡng chuyển đơn vị: không bao giờ được hiện "1000 m".
      expect(formatDistance(997), '1,0 km');
      expect(formatDistance(949), '950 m');
      expect(formatDistance(12400), '12 km');
      expect(formatDuration(const Duration(minutes: 95)), '1 giờ 35 phút');
      expect(formatDuration(const Duration(seconds: 20)), '1 phút');
    });
  });
}
