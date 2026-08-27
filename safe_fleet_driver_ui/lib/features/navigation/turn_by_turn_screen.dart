import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/ui.dart';
import '../../models/driver_models.dart';
import '../agent/agent_chat_screen.dart';
import '../flood/flood_report_screen.dart';
import 'engine/guidance_planner.dart';
import 'engine/nav_route.dart';
import 'engine/navigation_engine.dart';
import 'engine/route_simulator.dart';
import 'engine/voice_guidance.dart';
import 'route_offline_map_cache.dart';
import 'widgets/guidance_widgets.dart';

/// Turn-by-turn guidance.
///
/// Everything that decides what the driver sees and hears lives in
/// `engine/` and is exercised by a replayed drive in the test suite; this
/// widget only binds that engine to GPS, the map, the speaker and the backend.
class TurnByTurnScreen extends ConsumerStatefulWidget {
  const TurnByTurnScreen({
    super.key,
    required this.session,
    required this.destination,
  });

  final NavSession session;
  final LocationPoint destination;

  @override
  ConsumerState<TurnByTurnScreen> createState() => _TurnByTurnScreenState();
}

class _TurnByTurnScreenState extends ConsumerState<TurnByTurnScreen> {
  static const _eventMinInterval = Duration(seconds: 6);
  static const _eventMinDistanceMeters = 120.0;
  static const _rerouteCooldown = Duration(seconds: 20);

  late NavSession _session;
  late NavigationEngine _engine;
  late GuidancePlanner _planner;
  final VoiceGuidance _voice = VoiceGuidance();

  MapLibreMapController? _map;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _simulationTimer;

  NavState? _state;
  bool _styleReady = false;
  bool _online = true;
  bool _rerouting = false;
  bool _agentOpen = false;
  bool _reportingSegment = false;
  bool _finishing = false;
  bool _muted = false;
  bool _simulating = false;
  double _simulationOffset = 0;
  DateTime? _lastEventAt;
  double _lastEventOffset = -1000;
  DateTime? _lastRerouteAt;
  DateTime? _lastCameraAt;
  String? _error;

  NavRoute get _route => _engine.route;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _engine = NavigationEngine(
      route: _session.selected,
      destination: LatLng(widget.destination.lat, widget.destination.lng),
    );
    _planner = GuidancePlanner(destinationName: widget.destination.name);
    unawaited(_start());
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _positionSubscription?.cancel();
    unawaited(_voice.dispose());
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  Future<void> _start() async {
    await _voice.initialize();
    // A driver cannot tap the screen awake while steering, and a dark screen
    // mid-junction is worse than a dimmed one.
    unawaited(WakelockPlus.enable());
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Cần quyền vị trí để dẫn đường');
      }
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      _onPosition(current);
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 5,
            ),
          ).listen(
            _onPosition,
            onError: (Object _) {
              if (mounted) setState(() => _error = 'Mất tín hiệu GPS');
            },
          );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _onPosition(Position position) => _consume(
    NavFix(
      position: LatLng(position.latitude, position.longitude),
      timestamp: position.timestamp,
      accuracyMeters: position.accuracy,
      headingDeg: position.heading.isFinite && position.heading >= 0
          ? position.heading
          : null,
      speedMps: position.speed.isFinite && position.speed > 0
          ? position.speed
          : 0,
    ),
  );

  void _consume(NavFix fix) {
    if (!mounted) return;
    final state = _engine.update(fix);
    _voice.enqueueAll(_planner.plan(state));
    setState(() => _state = state);
    unawaited(_followCamera(state));

    if (state.arrived) {
      unawaited(_finish('ARRIVED'));
      return;
    }
    if (state.rerouteRequired) {
      unawaited(_reroute(fix, 'OFF_ROUTE_CONFIRMED'));
      return;
    }
    unawaited(_reportProgress(fix, state));
  }

  Future<void> _followCamera(NavState state) async {
    final map = _map;
    if (map == null || !_styleReady) return;
    final now = DateTime.now();
    // The camera is the most expensive thing on this screen; one move per
    // second is smooth enough and leaves the frame budget to the map itself.
    if (_lastCameraAt != null && now.difference(_lastCameraAt!).inMilliseconds < 900) {
      return;
    }
    _lastCameraAt = now;
    await map.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: state.snapped,
          zoom: state.speedKph > 70 ? 16 : 17,
          tilt: 55,
          bearing: state.courseDeg,
        ),
      ),
      duration: const Duration(milliseconds: 850),
    );
  }

  /// Pings the backend with progress. Throttled by both time and distance: the
  /// previous build sent one request per GPS fix, roughly twice a second at
  /// road speed.
  Future<void> _reportProgress(NavFix fix, NavState state) async {
    final now = DateTime.now();
    final movedEnough =
        (state.travelledMeters - _lastEventOffset).abs() >= _eventMinDistanceMeters;
    final waitedEnough =
        _lastEventAt == null || now.difference(_lastEventAt!) >= _eventMinInterval;
    if (!movedEnough && !waitedEnough) return;
    _lastEventAt = now;
    _lastEventOffset = state.travelledMeters;

    try {
      final response = await ref
          .read(driverRepositoryProvider)
          .navigationEventAt(
            sessionId: _session.sessionId,
            latitude: fix.position.latitude,
            longitude: fix.position.longitude,
            distanceToRouteMeters: state.lateralMeters,
            gpsAccuracyMeters: fix.accuracyMeters,
            occurredAt: fix.timestamp,
          );
      if (!mounted) return;
      if (!_online) setState(() => _online = true);
      if (response['rerouteRequired'] == true) {
        await _reroute(fix, 'HAZARD_AHEAD');
      }
    } catch (_) {
      // Offline is a normal state on a Vietnamese highway: the cached route,
      // steps, hazards and voice keep working, only fresh reports stop.
      if (mounted && _online) setState(() => _online = false);
    }
  }

  Future<void> _reroute(NavFix fix, String reason, {bool force = false}) async {
    if (_rerouting) return;
    final now = DateTime.now();
    if (!force &&
        _lastRerouteAt != null &&
        now.difference(_lastRerouteAt!) < _rerouteCooldown) {
      return;
    }
    _lastRerouteAt = now;
    setState(() => _rerouting = true);
    _voice.say(
      switch (reason) {
        'HAZARD_AHEAD' => 'Phát hiện đường bị chặn phía trước, đang tìm tuyến tránh',
        'FLOOD_REPORTED' => 'Đã ghi nhận đoạn ngập, đang tìm đường vòng',
        _ => 'Đang tính lại tuyến đường',
      },
      priority: GuidancePriority.urgent,
    );
    try {
      final session = await ref
          .read(driverRepositoryProvider)
          .rerouteAt(
            sessionId: _session.sessionId,
            latitude: fix.position.latitude,
            longitude: fix.position.longitude,
            gpsAccuracyMeters: fix.accuracyMeters,
            reason: reason,
          );
      if (!mounted || session.isEmpty) return;
      setState(() {
        _session = session;
        _online = true;
        _error = null;
      });
      _engine.replaceRoute(session.selected, at: fix.position);
      _planner.onRouteReplaced();
      await _drawRoute();
      unawaited(RouteOfflineMapCache.ensure(session));
      _voice.say('Đã có tuyến mới', priority: GuidancePriority.urgent);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _online = false;
        _error = reason == 'HAZARD_AHEAD'
            ? 'Đường phía trước bị chặn và chưa tìm được lối vòng an toàn. Hãy dừng xe ở nơi an toàn.'
            : 'Đang ngoại tuyến, chưa tính lại được tuyến. Hãy quay lại đường màu xanh đã tải.';
      });
      _voice.say(
        reason == 'HAZARD_AHEAD'
            ? 'Chưa tìm thấy đường tránh an toàn. Hãy dừng xe.'
            : 'Chưa tính lại được tuyến, hãy quay lại tuyến cũ',
        priority: GuidancePriority.urgent,
      );
    } finally {
      if (mounted) setState(() => _rerouting = false);
    }
  }

  Future<void> _finish(String reason) async {
    if (_finishing) return;
    _finishing = true;
    _positionSubscription?.cancel();
    _simulationTimer?.cancel();
    try {
      await ref
          .read(driverRepositoryProvider)
          .completeNavigation(sessionId: _session.sessionId, reason: reason);
    } catch (_) {
      // The session is closed on the next successful route request anyway.
    }
    if (!mounted) return;
    if (reason != 'ARRIVED') {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  Future<void> _drawRoute() async {
    final map = _map;
    if (map == null || !_styleReady) return;
    await map.clearLines();
    await map.clearCircles();

    final geometry = _route.geometry;
    if (geometry.length >= 2) {
      // A casing under the route line keeps it readable over dark satellite
      // imagery and over pale road fills alike.
      await map.addLine(
        LineOptions(
          geometry: geometry,
          lineColor: sfHex(SfColors.darkBg),
          lineWidth: 11,
          lineOpacity: .85,
        ),
      );
      await map.addLine(
        LineOptions(
          geometry: geometry,
          lineColor: sfHex(SfColors.green400),
          lineWidth: 7,
          lineOpacity: .98,
        ),
      );
    }

    for (final hazard in _route.hazardsOnRoute) {
      if (!hazard.onRoute) continue;
      await map.addCircle(
        CircleOptions(
          geometry: hazard.hazard.center,
          circleRadius: 9,
          circleColor: sfHex(
            hazard.hazard.hardClosure ? SfColors.danger : SfColors.warning,
          ),
          circleStrokeColor: sfHex(SfColors.surface),
          circleStrokeWidth: 2,
        ),
      );
    }

    await map.addCircle(
      CircleOptions(
        geometry: geometry.isEmpty
            ? LatLng(widget.destination.lat, widget.destination.lng)
            : geometry.last,
        circleRadius: 8,
        circleColor: sfHex(SfColors.green700),
        circleStrokeColor: sfHex(SfColors.surface),
        circleStrokeWidth: 3,
      ),
    );
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _voice.setMuted(_muted);
  }

  /// Replays the selected route through the same engine the real GPS feeds, so
  /// a route can be rehearsed - and the guidance verified - without driving it.
  void _toggleSimulation() {
    if (_simulating) {
      _simulationTimer?.cancel();
      setState(() => _simulating = false);
      return;
    }
    _positionSubscription?.pause();
    _simulationOffset = _state?.travelledMeters ?? 0;
    setState(() => _simulating = true);
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted || !_simulating) {
        timer.cancel();
        return;
      }
      _simulationOffset += 16;
      if (_simulationOffset > _route.lengthMeters) {
        _simulationOffset = _route.lengthMeters;
        timer.cancel();
      }
      _consume(
        NavFix(
          position: RouteSimulator.pointAt(_route, _simulationOffset),
          timestamp: DateTime.now(),
          accuracyMeters: 6,
          headingDeg: RouteSimulator.bearingAt(_route, _simulationOffset),
          speedMps: 16 / 0.7,
        ),
      );
    });
  }

  /// Offers the two ways a driver reports a road they cannot pass.
  ///
  /// The first marks the stretch of the current route around the vehicle, which
  /// is what a flooded street actually is - a segment, not a pin. The backend
  /// turns it into a narrow corridor the router must avoid, so every driver
  /// behind this one is routed around it too.
  Future<void> _reportHazardHere() async {
    if (_reportingSegment) return;
    final choice = await showModalBottomSheet<_HazardReportChoice>(
      context: context,
      backgroundColor: SfColors.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: SfRadius.heroR),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SfSpace.x16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Báo tình trạng đường',
                style: SfType.titleCard.copyWith(
                  color: SfColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: SfSpace.x14),
              SfPrimaryAction(
                label: 'Đoạn đang đi bị ngập',
                icon: Icons.add_road_rounded,
                onPressed: () =>
                    Navigator.pop(sheetContext, _HazardReportChoice.segment),
              ),
              const SizedBox(height: SfSpace.x10),
              SfPrimaryAction(
                label: 'Mở biểu mẫu chi tiết',
                icon: Icons.edit_note_rounded,
                tone: SfColors.info,
                onPressed: () =>
                    Navigator.pop(sheetContext, _HazardReportChoice.form),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == _HazardReportChoice.form) {
      await _openHazardForm();
    } else {
      await _reportFloodedSegment();
    }
  }

  Future<void> _openHazardForm() async {
    setState(() => _reportingSegment = true);
    try {
      await Navigator.of(context).push<void>(
        SfSlideRoute<void>(builder: (_) => const FloodReportScreen()),
      );
      if (!mounted) return;
      // The report just filed may sit on the road ahead. Clearing the throttle
      // makes the next ping ask the backend to re-score immediately, and the
      // answer decides whether a detour is warranted.
      _lastEventAt = null;
      _lastEventOffset = -1000;
      final state = _state;
      if (state != null) await _reportProgress(_fixFrom(state), state);
    } finally {
      if (mounted) setState(() => _reportingSegment = false);
    }
  }

  Future<void> _reportFloodedSegment() async {
    final state = _state;
    final segment = state == null ? const <LatLng>[] : _segmentAround(state);
    if (state == null || segment.length < 2) {
      showError(context, 'Chưa đủ GPS hoặc hình học tuyến để báo đoạn ngập.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Báo đoạn đường đang ngập?'),
        content: const Text(
          'Hệ thống đánh dấu đoạn tuyến quanh vị trí hiện tại, tìm ngay đường '
          'vòng cho bạn và loại đoạn này khỏi tuyến của các tài xế khác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huỷ'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.add_road_rounded),
            label: const Text('Xác nhận báo ngập'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reportingSegment = true);
    try {
      final result = await ref
          .read(driverRepositoryProvider)
          .reportFloodSegmentAt(
            latitude: state.snapped.latitude,
            longitude: state.snapped.longitude,
            geometry: segment
                .map(
                  (point) => <String, double>{
                    'lat': point.latitude,
                    'lng': point.longitude,
                  },
                )
                .toList(),
          );
      if (!mounted) return;
      final queued = result['queued'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? 'Đã lưu đoạn ngập, sẽ tự đồng bộ khi có mạng'
                : 'Đã gửi đoạn ngập, đang tìm đường vòng',
          ),
        ),
      );
      if (!queued) {
        await _reroute(_fixFrom(state), 'FLOOD_REPORTED', force: true);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _reportingSegment = false);
    }
  }

  /// The stretch of route within ~120 m either side of the vehicle.
  List<LatLng> _segmentAround(NavState state) {
    final cumulative = _route.cumulativeMeters;
    final geometry = _route.geometry;
    if (geometry.length < 2) return const [];
    const halfWindow = 120.0;
    final from = state.travelledMeters - halfWindow;
    final to = state.travelledMeters + halfWindow;
    final selected = <LatLng>[];
    for (var index = 0; index < geometry.length; index++) {
      if (cumulative[index] >= from && cumulative[index] <= to) {
        selected.add(geometry[index]);
      }
    }
    if (selected.length >= 2) return selected;
    // A sparse polyline can leave no vertex inside the window; fall back to the
    // segment the vehicle is matched onto.
    final index = geometry.length > 1 ? 1 : 0;
    return [geometry[index - 1], geometry[index]];
  }

  NavFix _fixFrom(NavState state) => NavFix(
    position: state.snapped,
    timestamp: DateTime.now(),
    accuracyMeters: 8,
    headingDeg: state.courseDeg,
    speedMps: state.speedKph / 3.6,
  );

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return SfTheme.darkWrap(
      child: Scaffold(
        backgroundColor: SfColors.darkBg,
        body: Stack(
          children: [
            Positioned.fill(
              child: MapLibreMap(
                styleString: AppConfig.mapStyleUrlDark,
                initialCameraPosition: CameraPosition(
                  target: _route.geometry.isEmpty
                      ? LatLng(widget.destination.lat, widget.destination.lng)
                      : _route.geometry.first,
                  zoom: 16,
                  tilt: 55,
                ),
                myLocationEnabled: true,
                myLocationRenderMode: MyLocationRenderMode.compass,
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                onMapCreated: (controller) => _map = controller,
                onStyleLoadedCallback: () async {
                  _styleReady = true;
                  await _drawRoute();
                },
              ),
            ),
            if (AppConfig.needsDarkMapOverlay)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Color(0x33000000)),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SfSpace.x12,
                      SfSpace.x12,
                      SfSpace.x12,
                      0,
                    ),
                    child: NavigationInstructionBanner(
                      state: state,
                      rerouting: _rerouting,
                    ),
                  ),
                  if (state?.hazardAhead != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SfSpace.x12,
                        SfSpace.x8,
                        SfSpace.x12,
                        0,
                      ),
                      child: NavigationHazardBanner(
                        hazard: state!.hazardAhead!,
                        distanceMeters: state.hazardDistanceMeters ?? 0,
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SfSpace.x12,
                        SfSpace.x8,
                        SfSpace.x12,
                        0,
                      ),
                      child: SfInfoBox(
                        icon: Icons.warning_amber_rounded,
                        text: _error!,
                        status: SfStatus.danger,
                      ),
                    ),
                  const Spacer(),
                  if (state?.arrived == true)
                    Padding(
                      padding: const EdgeInsets.all(SfSpace.x12),
                      child: NavigationArrivalCard(
                        destination: widget.destination.name,
                        onClose: () => Navigator.of(context).maybePop(),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(SfSpace.x12),
                      child: NavigationProgressDock(
                        state: state,
                        route: _route,
                        online: _online,
                        muted: _muted,
                        simulating: _simulating,
                        reporting: _reportingSegment,
                        onMute: _toggleMute,
                        onSimulate: kDebugMode ? _toggleSimulation : null,
                        onReport: _reportHazardHere,
                        onAgent: () => setState(() => _agentOpen = true),
                        onStop: () => _finish('CANCELLED'),
                      ),
                    ),
                ],
              ),
            ),
            if (_agentOpen)
              Positioned.fill(
                child: AgentChatScreen(
                  onClose: () => setState(() => _agentOpen = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _HazardReportChoice { segment, form }
