@Tags(['preview'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe_fleet_driver_ui/core/widgets/ui.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/nav_route.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/navigation_engine.dart';
import 'package:safe_fleet_driver_ui/features/navigation/engine/route_simulator.dart';
import 'package:safe_fleet_driver_ui/features/navigation/widgets/guidance_widgets.dart';

/// Renders the guidance surfaces to PNG so a change can be reviewed by eye
/// rather than only by assertion.
///
/// Skipped by default because it depends on a system font being present; run
/// it deliberately with:
///
/// ```
/// SF_RENDER_PREVIEW=1 flutter test test/navigation_preview_test.dart --update-goldens
/// ```
bool get _enabled => Platform.environment['SF_RENDER_PREVIEW'] == '1';

/// The faces bundled in `assets/google_fonts`, registered under the family
/// names google_fonts derives from the weight.
const _faces = <String>[
  'BeVietnamPro-Light',
  'BeVietnamPro-Regular',
  'BeVietnamPro-Medium',
  'BeVietnamPro-SemiBold',
  'BeVietnamPro-Bold',
  'BeVietnamPro-ExtraBold',
];

Future<void> _loadRealFont() async {
  // The test harness draws boxes with its placeholder font, and nothing may
  // reach the network from a test, so the shipped faces are loaded directly.
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final face in _faces) {
    final file = File('assets/google_fonts/$face.ttf');
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(face)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
  await _loadMaterialIcons();
}

/// Turn arrows are the point of this preview, so the icon font has to be real
/// too. It ships inside the SDK rather than the project.
Future<void> _loadMaterialIcons() async {
  final roots = <String>[
    Platform.environment['FLUTTER_ROOT'] ?? '',
    File(Platform.resolvedExecutable).parent.parent.parent.parent.path,
  ].where((root) => root.isNotEmpty);
  final candidates = [
    for (final root in roots)
      File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf'),
  ];
  final font = candidates.firstWhere(
    (file) => file.existsSync(),
    orElse: () => File(''),
  );
  if (font.path.isEmpty) return;
  final bytes = font.readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Map<String, dynamic> _routeJson({bool fallback = false}) {
  final geometry = <List<double>>[];
  for (var index = 0; index <= 60; index++) {
    geometry.add([105.8542 + index * 0.00024, 21.0285]);
  }
  return <String, dynamic>{
    'routeIndex': 0,
    'provider': fallback ? 'OSRM' : 'VALHALLA',
    'fallback': fallback,
    'safe': true,
    'distanceMeters': 1500,
    'durationSeconds': 900,
    'geometry': geometry,
    'steps': [
      {
        'instruction': 'Bắt đầu đi trên Đường Láng',
        'roadName': 'Đường Láng',
        'maneuver': 'DEPART',
        'beginShapeIndex': 0,
      },
      {
        'instruction': 'Rẽ phải vào Phố Huế',
        'roadName': 'Phố Huế',
        'maneuver': 'TURN_RIGHT',
        'beginShapeIndex': 30,
      },
      {
        'instruction': 'Rẽ trái vào Ngõ 12 Trần Duy Hưng',
        'roadName': 'Ngõ 12 Trần Duy Hưng',
        'maneuver': 'TURN_LEFT',
        'beginShapeIndex': 44,
      },
      {
        'instruction': 'Đã đến điểm đến',
        'roadName': '',
        'maneuver': 'ARRIVE',
        'beginShapeIndex': 60,
      },
    ],
  };
}

Widget _frame(List<Widget> children) => MediaQuery(
  data: const MediaQueryData(size: Size(390, 760), devicePixelRatio: 2),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SfTheme.darkWrap(
      child: Scaffold(
        backgroundColor: const Color(0xFF12181C),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in children) ...[
                  child,
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(_loadRealFont);

  testWidgets('preview: guidance while approaching a turn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    final route = NavRoute.fromJson(_routeJson())!;
    final engine = NavigationEngine(route: route, destination: route.geometry.last);
    NavState? state;
    for (final fix in RouteSimulator.drive(route, speedMps: 11, toOffset: 520)) {
      state = engine.update(fix);
    }

    await tester.pumpWidget(
      _frame([
        NavigationInstructionBanner(state: state),
        const Spacer(),
        NavigationProgressDock(
          state: state,
          route: route,
          online: true,
          muted: false,
          onMute: () {},
          onStop: () {},
          onReport: () {},
          onAgent: () {},
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('preview/navigation_guiding.png'),
    );
  }, skip: !_enabled);

  testWidgets('preview: closure ahead on a degraded route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    final json = _routeJson(fallback: true);
    final base = NavRoute.fromJson(json)!;
    final hazard = NavHazard(
      id: 42,
      hazardType: 'FLOOD',
      severity: 'BLOCKED',
      hardClosure: true,
      geometry: [RouteSimulator.pointAt(base, 900)],
      radiusMeters: 60,
      address: 'Ngã tư Sở',
    );
    final route = NavRoute.fromJson(json, hazards: [hazard])!;
    final engine = NavigationEngine(route: route, destination: route.geometry.last);
    NavState? state;
    for (final fix in RouteSimulator.drive(route, speedMps: 11, toOffset: 520)) {
      state = engine.update(fix);
    }

    await tester.pumpWidget(
      _frame([
        NavigationInstructionBanner(state: state),
        NavigationHazardBanner(
          hazard: state!.hazardAhead!,
          distanceMeters: state.hazardDistanceMeters ?? 0,
        ),
        const Spacer(),
        NavigationProgressDock(
          state: state,
          route: route,
          online: false,
          muted: false,
          onMute: () {},
          onStop: () {},
          onReport: () {},
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('preview/navigation_hazard.png'),
    );
  }, skip: !_enabled);

  testWidgets('preview: off route and recalculating', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    final route = NavRoute.fromJson(_routeJson())!;
    final engine = NavigationEngine(route: route, destination: route.geometry.last);
    NavState? state;
    for (final fix in RouteSimulator.drive(route, speedMps: 11, toOffset: 400)) {
      state = engine.update(fix);
    }
    for (final fix in RouteSimulator.divert(
      route,
      fromOffset: 400,
      distanceMeters: 320,
      speedMps: 11,
      startAt: DateTime(2026, 1, 1, 8, 5),
    )) {
      state = engine.update(fix);
    }

    await tester.pumpWidget(
      _frame([
        NavigationInstructionBanner(state: state, rerouting: true),
        const Spacer(),
        NavigationArrivalCard(destination: 'Kho Gia Lâm', onClose: () {}),
      ]),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('preview/navigation_offroute.png'),
    );
  }, skip: !_enabled);
}
