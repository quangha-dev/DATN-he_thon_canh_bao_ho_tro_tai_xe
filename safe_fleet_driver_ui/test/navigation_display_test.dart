import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/maneuver.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/nav_route.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/navigation_engine.dart';
import 'package:safe_fleet_driver_ui/features/navigation/widgets/guidance_widgets.dart';
import 'package:safe_fleet_driver_ui/features/navigation/widgets/navigation_resume_card.dart';

/// A straight 1 km route with one right turn 600 m in.
Map<String, dynamic> _routeJson({
  String provider = 'VALHALLA',
  bool fallback = false,
}) {
  final geometry = <List<double>>[];
  for (var index = 0; index <= 40; index++) {
    geometry.add([105.8542 + index * 0.00024, 21.0285]);
  }
  return <String, dynamic>{
    'routeIndex': 0,
    'label': 'Đề xuất ít rủi ro nhất',
    'provider': provider,
    'fallback': fallback,
    'safe': true,
    'distanceMeters': 1000,
    'durationSeconds': 600,
    'geometry': geometry,
    'steps': [
      {
        'instruction': 'Bắt đầu đi trên Đường Láng',
        'roadName': 'Đường Láng',
        'maneuver': 'DEPART',
        'beginShapeIndex': 0,
        'distanceMeters': 600,
      },
      {
        'instruction': 'Rẽ phải vào Phố Huế',
        'roadName': 'Phố Huế',
        'maneuver': 'TURN_RIGHT',
        'beginShapeIndex': 24,
        'distanceMeters': 400,
      },
      {
        'instruction': 'Đã đến điểm đến',
        'roadName': '',
        'maneuver': 'ARRIVE',
        'beginShapeIndex': 40,
        'distanceMeters': 0,
      },
    ],
  };
}

NavRoute _route({String provider = 'VALHALLA', bool fallback = false}) =>
    NavRoute.fromJson(_routeJson(provider: provider, fallback: fallback))!;

NavState _stateAt(NavRoute route, double offsetMeters, {double speedMps = 11}) {
  final engine = NavigationEngine(
    route: route,
    destination: route.geometry.last,
  );
  final scale = 0.00024;
  final index = (offsetMeters / route.lengthMeters * 40).clamp(0, 40).toDouble();
  return engine.update(
    NavFix(
      position: LatLng(21.0285, 105.8542 + index * scale),
      timestamp: DateTime(2026, 1, 1, 8),
      accuracyMeters: 8,
      headingDeg: 90,
      speedMps: speedMps,
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF101418),
        body: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('banner leads with the distance to the next turn', (tester) async {
    final route = _route();
    final state = _stateAt(route, 300);

    await _pump(tester, NavigationInstructionBanner(state: state));

    expect(find.text('Rẽ phải vào Phố Huế'), findsOneWidget);
    // The turn is 600 m in and the vehicle is at 300 m.
    expect(find.text('300 m'), findsOneWidget);
    // The arrow reflects the normalised maneuver rather than defaulting to a
    // straight-ahead icon, which is what the raw provider code used to produce.
    expect(
      tester.widget<Icon>(find.byIcon(SfManeuver.right.icon)).icon,
      Icons.turn_right_rounded,
    );
  });

  testWidgets('banner previews the maneuver after the next one', (tester) async {
    final route = _route();
    final state = _stateAt(route, 300);

    await _pump(tester, NavigationInstructionBanner(state: state));

    expect(find.textContaining('Sau đó'), findsOneWidget);
  });

  testWidgets('banner switches to a recovery message when off route', (
    tester,
  ) async {
    final route = _route();
    final engine = NavigationEngine(
      route: route,
      destination: route.geometry.last,
    );
    NavState? state;
    for (var second = 0; second < 30; second++) {
      state = engine.update(
        NavFix(
          // 300 m north of the route.
          position: LatLng(21.0285 + 0.0027, 105.8542 + second * 0.00024),
          timestamp: DateTime(2026, 1, 1, 8).add(Duration(seconds: second)),
          accuracyMeters: 8,
          headingDeg: 90,
          speedMps: 11,
        ),
      );
    }

    await _pump(tester, NavigationInstructionBanner(state: state));

    expect(find.textContaining('lệch tuyến'), findsOneWidget);
    expect(find.text('Rẽ phải vào Phố Huế'), findsNothing);
  });

  testWidgets('banner announces the recalculation while it runs', (tester) async {
    final route = _route();
    await _pump(
      tester,
      NavigationInstructionBanner(state: _stateAt(route, 100), rerouting: true),
    );

    expect(find.text('Đang tìm tuyến mới…'), findsOneWidget);
  });

  testWidgets('dock shows eta, remaining distance and the offline state', (
    tester,
  ) async {
    final route = _route();
    final state = _stateAt(route, 400);

    await _pump(
      tester,
      NavigationProgressDock(
        state: state,
        route: route,
        online: false,
        muted: false,
        onMute: () {},
        onStop: () {},
      ),
    );

    // SfStatusPill renders its label upper-cased.
    expect(find.text('NGOẠI TUYẾN'), findsOneWidget);
    expect(find.textContaining('600 m'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('a degraded route is labelled so it is not read as flood-checked', (
    tester,
  ) async {
    final route = _route(provider: 'OSRM', fallback: true);

    await _pump(
      tester,
      NavigationProgressDock(
        state: _stateAt(route, 100),
        route: route,
        online: true,
        muted: true,
        onMute: () {},
        onStop: () {},
      ),
    );

    expect(find.text('TUYẾN SUY GIẢM'), findsOneWidget);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
  });

  testWidgets('hazard banner states the kind, the distance and the place', (
    tester,
  ) async {
    final hazard = NavHazardOnRoute(
      hazard: NavHazard(
        id: 7,
        hazardType: 'FLOOD',
        severity: 'BLOCKED',
        hardClosure: true,
        geometry: const [LatLng(21.0285, 105.8600)],
        radiusMeters: 80,
        address: 'Ngã tư Sở',
      ),
      offsetMeters: 700,
      clearanceMeters: 0,
    );

    await _pump(
      tester,
      NavigationHazardBanner(hazard: hazard, distanceMeters: 420),
    );

    expect(find.textContaining('Đường bị chặn'), findsOneWidget);
    expect(find.textContaining('ngập nước'), findsOneWidget);
    expect(find.textContaining('420 m'), findsOneWidget);
    expect(find.textContaining('Ngã tư Sở'), findsOneWidget);
  });

  testWidgets('arrival card offers the one action left to take', (tester) async {
    var closed = false;
    await _pump(
      tester,
      NavigationArrivalCard(
        destination: 'Kho Gia Lâm',
        onClose: () => closed = true,
      ),
    );

    expect(find.text('Đã đến Kho Gia Lâm'), findsOneWidget);
    await tester.tap(find.text('Kết thúc dẫn đường'));
    expect(closed, isTrue);
  });

  group('quay lại phiên dẫn đường đang mở', () {
    Future<void> pumpCard(WidgetTester tester, NavSession? session) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeNavigationProvider.overrideWith((ref) async => session),
          ],
          child: const MaterialApp(
            home: Scaffold(body: NavigationResumeCard()),
          ),
        ),
      );
      await tester.pump();
    }

    NavSession sessionWith({bool fallback = false}) => NavSession.fromJson({
      'sessionId': 'session-dang-chay',
      'selectedRouteIndex': 0,
      'destinationLat': 21.03,
      'destinationLng': 105.86,
      'destinationName': 'Kho Gia Lâm',
      'routes': [_routeJson(fallback: fallback)],
    });

    testWidgets('không có phiên nào thì không chiếm chỗ trên màn Nhà', (
      tester,
    ) async {
      await pumpCard(tester, null);

      expect(find.textContaining('Đang dẫn đường'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('có phiên thì mời tài xế quay lại đúng điểm đến', (
      tester,
    ) async {
      await pumpCard(tester, sessionWith());

      expect(find.text('Đang dẫn đường'), findsOneWidget);
      expect(find.text('Kho Gia Lâm'), findsOneWidget);
      expect(find.textContaining('1,0 km'), findsOneWidget);
      expect(find.text('Tiếp tục dẫn đường'), findsOneWidget);
    });

    testWidgets('phiên chạy trên tuyến suy giảm phải nói rõ ngay ở màn Nhà', (
      tester,
    ) async {
      await pumpCard(tester, sessionWith(fallback: true));

      expect(find.text('TUYẾN SUY GIẢM'), findsOneWidget);
    });
  });

  group('session parsing', () {
    test('picks the alternative the backend recommends', () {
      final session = NavSession.fromJson({
        'sessionId': 'session-1',
        'safe': true,
        'selectedRouteIndex': 1,
        'destinationLat': 21.03,
        'destinationLng': 105.86,
        'destinationName': 'Kho Gia Lâm',
        'routes': [
          {..._routeJson(), 'routeIndex': 0, 'provider': 'OSRM'},
          {..._routeJson(), 'routeIndex': 1, 'provider': 'VALHALLA'},
        ],
      });

      expect(session.routes, hasLength(2));
      expect(session.selected.provider, 'VALHALLA');
      expect(session.destinationName, 'Kho Gia Lâm');
      expect(session.selectRoute(0).selected.provider, 'OSRM');
    });

    test('drops candidates with unusable geometry instead of crashing', () {
      final session = NavSession.fromJson({
        'sessionId': 'session-2',
        'selectedRouteIndex': 0,
        'routes': [
          {'routeIndex': 0, 'geometry': <dynamic>[]},
          {..._routeJson(), 'routeIndex': 1},
        ],
      });

      expect(session.routes, hasLength(1));
      expect(session.isEmpty, isFalse);
    });

    test('resolves the frozen hazard snapshot against each route', () {
      final session = NavSession.fromJson({
        'sessionId': 'session-3',
        'selectedRouteIndex': 0,
        'routes': [_routeJson()],
        'hazards': [
          {
            'id': 9,
            'hazardType': 'FLOOD',
            'severity': 'BLOCKED',
            'hardClosure': true,
            'geometryType': 'POINT',
            'lat': 21.0285,
            'lng': 105.8542 + 20 * 0.00024,
            'radiusMeters': 50,
            'geometry': <dynamic>[],
          },
          {
            'id': 10,
            'hazardType': 'TRAFFIC_JAM',
            'severity': 'MEDIUM',
            'hardClosure': false,
            'geometryType': 'POINT',
            // Two kilometres north — nowhere near this route.
            'lat': 21.0465,
            'lng': 105.8542,
            'radiusMeters': 50,
            'geometry': <dynamic>[],
          },
        ],
      });

      expect(session.hazards, hasLength(2));
      // Only the one actually sitting on the road counts.
      expect(session.selected.hazardsOnRouteCount, 1);
      expect(
        session.selected.hazardsOnRoute
            .firstWhere((item) => item.onRoute)
            .hazard
            .id,
        9,
      );
    });
  });
}
