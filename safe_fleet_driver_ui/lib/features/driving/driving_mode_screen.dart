import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../app.dart';
import '../../core/config/app_config.dart';
import '../../core/agent/agent_conversation_provider.dart';
import '../../core/ai/cabin_safety_provider.dart';
import '../../core/ai/stgt_drowsiness_engine.dart';
import '../../core/widgets/ui.dart';
import '../camera/cabin_camera_screen.dart';
import '../agent/agent_chat_screen.dart';
import '../flood/flood_report_screen.dart';
import '../incidents/sos_screen.dart';
import '../navigation/engine/guidance_planner.dart';
import '../navigation/engine/nav_route.dart';
import '../navigation/engine/navigation_engine.dart';
import '../navigation/engine/voice_guidance.dart';

/// Chế độ lái — màn duy nhất tài xế nhìn khi xe đang chạy.
///
/// Luôn nền tối. Mọi chữ >= 18px, mọi vùng chạm >= 64dp, không có gì trượt
/// ngang trong tầm mắt. Một thông tin quan trọng nhất mỗi lúc: khoảng cách tới
/// khúc rẽ kế tiếp.
class DrivingModeScreen extends ConsumerStatefulWidget {
  const DrivingModeScreen({required this.trip, super.key});

  final Map<String, dynamic> trip;

  @override
  ConsumerState<DrivingModeScreen> createState() => _DrivingModeScreenState();
}

class _DrivingModeScreenState extends ConsumerState<DrivingModeScreen> {
  MapLibreMapController? _map;
  StreamSubscription<Position>? _positionSubscription;

  /// Guidance runs on the same engine as the standalone turn-by-turn screen,
  /// so a trip and an ad-hoc route behave identically - including map matching,
  /// off-route confirmation and voice tiering.
  NavSession? _navigation;
  NavigationEngine? _engine;
  GuidancePlanner? _planner;
  final VoiceGuidance _voice = VoiceGuidance();
  NavState? _navState;
  DateTime? _lastNavEventAt;
  DateTime? _lastRerouteAt;
  bool _rerouting = false;
  Position? _position;
  String _gps = 'Đang định vị';
  bool _online = true;
  int _queueCount = 0;
  bool _paused = false;
  bool _busy = true;
  bool _styleLoaded = false;
  DateTime? _lastTelemetry;
  bool _enabledWakeForDrive = false;
  bool _leavingDriveMode = false;
  bool _wakeReady = false;

  final _sheetController = DraggableScrollableController();
  final _sheetSize = ValueNotifier<double>(_snaps.first);

  static const _snaps = [0.24, 0.55, 0.92];

  /// Phút lái liên tục kể từ lúc chuyến thực sự khởi hành — con số quyết định
  /// của một ca lái. Khi chưa có giờ khởi hành thật thì đếm từ lúc mở màn.
  final _driveStartedAt = DateTime.now();

  int get _continuousMinutes {
    final started =
        DateTime.tryParse(widget.trip['startTime']?.toString() ?? '') ??
        _driveStartedAt;
    final minutes = DateTime.now().difference(started).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  int get tripId => (widget.trip['id'] as num).toInt();
  int get vehicleId => (widget.trip['vehicleId'] as num).toInt();
  int get driverId => (widget.trip['driverId'] as num).toInt();

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(cabinSafetyProvider.notifier).start());
    unawaited(_startWakeListener());
    _sheetController.addListener(_onSheetMoved);
    _initialize();
  }

  @override
  void dispose() {
    _leavingDriveMode = true;
    unawaited(_stopWakeListener());
    unawaited(ref.read(cabinSafetyProvider.notifier).stop());
    _sheetController.removeListener(_onSheetMoved);
    _sheetController.dispose();
    _sheetSize.dispose();
    _positionSubscription?.cancel();
    unawaited(_voice.dispose());
    super.dispose();
  }

  Future<void> _startWakeListener() async {
    final controller = ref.read(agentConversationProvider.notifier);
    await controller.dismissOverlay();
    if (_leavingDriveMode || !mounted) return;
    final alreadyEnabled = ref.read(agentConversationProvider).wakeEnabled;
    if (!alreadyEnabled) {
      _enabledWakeForDrive = true;
      await controller.setWakeEnabled(true);
    }
    if (!_leavingDriveMode && mounted) setState(() => _wakeReady = true);
  }

  Future<void> _stopWakeListener() async {
    final controller = ref.read(agentConversationProvider.notifier);
    await controller.dismissOverlay();
    if (_enabledWakeForDrive) await controller.setWakeEnabled(false);
  }

  void _closeAgent() {
    unawaited(ref.read(agentConversationProvider.notifier).dismissOverlay());
  }

  void _onSheetMoved() {
    if (_sheetController.isAttached) _sheetSize.value = _sheetController.size;
  }

  Future<void> _initialize() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Hãy bật dịch vụ vị trí');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Ứng dụng cần quyền vị trí để dẫn đường');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _position = position;
      await _requestRoute(position);
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 8,
            ),
          ).listen(
            _onPosition,
            onError: (Object error) {
              if (mounted) setState(() => _gps = 'Mất GPS');
            },
          );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestRoute(Position position) async {
    final destinationLat = (widget.trip['endLat'] as num?)?.toDouble();
    final destinationLng = (widget.trip['endLng'] as num?)?.toDouble();
    if (destinationLat == null || destinationLng == null) {
      throw Exception('Chuyến chưa có tọa độ điểm đến');
    }
    final route = await ref
        .read(driverRepositoryProvider)
        .navigationRoute(
          originLat: position.latitude,
          originLng: position.longitude,
          destinationLat: destinationLat,
          destinationLng: destinationLng,
          destinationName: widget.trip['endLocation']?.toString() ?? 'Điểm đến',
          tripId: tripId,
        );
    if (!mounted || route.isEmpty) return;
    final destination = LatLng(destinationLat, destinationLng);
    setState(() {
      _navigation = route;
      _engine = NavigationEngine(route: route.selected, destination: destination);
      _planner = GuidancePlanner(
        destinationName: widget.trip['endLocation']?.toString(),
      );
    });
    unawaited(_voice.initialize());
    await _drawRoute();
  }

  Future<void> _onPosition(Position position) async {
    if (!mounted) return;
    setState(() {
      _position = position;
      _gps = position.accuracy <= 25 ? 'GPS tốt' : 'GPS yếu';
    });
    ref
        .read(cabinSafetyProvider.notifier)
        .updateSpeed(math.max(0, position.speed * 3.6));
    final engine = _engine;
    if (_paused || engine == null) return;

    final navState = engine.update(
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
    _voice.enqueueAll(_planner?.plan(navState) ?? const []);
    if (mounted) setState(() => _navState = navState);

    if (_lastTelemetry == null ||
        DateTime.now().difference(_lastTelemetry!) >=
            const Duration(seconds: 5)) {
      _lastTelemetry = DateTime.now();
      await ref
          .read(driverRepositoryProvider)
          .queueTelemetry(
            vehicleId: vehicleId,
            driverId: driverId,
            tripId: tripId,
            position: position,
          );
      final synced = await ref.read(syncQueueProvider).syncNow();
      if (mounted) {
        final count = await ref.read(databaseProvider).pendingCount();
        setState(() {
          _queueCount = count;
          _online = synced > 0 || count == 0;
        });
      }
    }
    // One request per GPS fix meant roughly two per second at road speed; the
    // backend only needs a progress ping often enough to spot a new closure.
    final now = DateTime.now();
    if (_lastNavEventAt != null &&
        now.difference(_lastNavEventAt!) < const Duration(seconds: 6)) {
      if (navState.rerouteRequired) await _reroute(position, 'OFF_ROUTE_CONFIRMED');
      return;
    }
    _lastNavEventAt = now;

    try {
      final event = await ref
          .read(driverRepositoryProvider)
          .navigationEvent(
            sessionId: _navigation!.sessionId,
            position: position,
            distanceToRouteMeters: navState.lateralMeters,
          );
      if (mounted && !_online) setState(() => _online = true);
      if (event['rerouteRequired'] == true) {
        await _reroute(position, 'HAZARD_AHEAD');
      } else if (navState.rerouteRequired) {
        await _reroute(position, 'OFF_ROUTE_CONFIRMED');
      }
    } catch (_) {
      if (mounted) setState(() => _online = false);
    }
  }

  Future<void> _reroute(Position position, String reason) async {
    if (_rerouting) return;
    final session = _navigation;
    if (session == null) return;
    final now = DateTime.now();
    if (_lastRerouteAt != null &&
        now.difference(_lastRerouteAt!) < const Duration(seconds: 20)) {
      return;
    }
    _lastRerouteAt = now;
    _rerouting = true;
    _voice.say(
      reason == 'HAZARD_AHEAD'
          ? 'Phát hiện đường bị chặn phía trước, đang tìm tuyến tránh'
          : 'Đang tính lại tuyến đường',
      priority: GuidancePriority.urgent,
    );
    try {
      final rerouted = await ref
          .read(driverRepositoryProvider)
          .reroute(
            sessionId: session.sessionId,
            position: position,
            reason: reason,
          );
      if (!mounted || rerouted.isEmpty) return;
      setState(() => _navigation = rerouted);
      _engine?.replaceRoute(
        rerouted.selected,
        at: LatLng(position.latitude, position.longitude),
      );
      _planner?.onRouteReplaced();
      await _drawRoute();
      _voice.say('Đã có tuyến mới', priority: GuidancePriority.urgent);
    } catch (_) {
      if (mounted) setState(() => _online = false);
      _voice.say(
        'Chưa tính lại được tuyến, hãy quay lại tuyến cũ',
        priority: GuidancePriority.urgent,
      );
    } finally {
      _rerouting = false;
    }
  }

  Future<void> _drawRoute() async {
    final session = _navigation;
    if (_map == null || !_styleLoaded || session == null || session.isEmpty) {
      return;
    }
    await _map!.clearLines();
    for (var index = 0; index < session.routes.length; index++) {
      final candidate = session.routes[index];
      if (candidate.geometry.length < 2) continue;
      final selected = index == session.selectedIndex;
      await _map!.addLine(
        LineOptions(
          geometry: candidate.geometry,
          // Trên nền tối, tuyến đang chạy dùng mint; các phương án khác lùi
          // hẳn về màu chữ mờ để không tranh chấp thị giác.
          lineColor: selected
              ? sfHex(SfColors.green400)
              : sfHex(SfColors.darkTextMuted),
          lineWidth: selected ? 7 : 3,
          lineOpacity: selected ? 0.95 : 0.45,
        ),
      );
    }
  }

  Future<void> _togglePause() async {
    setState(() => _busy = true);
    try {
      final action = _paused ? 'resume' : 'pause';
      await ref.read(driverRepositoryProvider).workflow(tripId, action);
      setState(() => _paused = !_paused);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: SfTheme.dark,
        child: AlertDialog(
          title: const Text('Hoàn thành chuyến?'),
          content: const Text(
            'Phiên lái và dẫn đường sẽ kết thúc, xe chuyển về trạng thái sẵn sàng.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Chưa xong'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hoàn thành'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(driverRepositoryProvider).workflow(tripId, 'complete');
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(agentConversationProvider);
    final initialLat =
        _position?.latitude ??
        (widget.trip['startLat'] as num?)?.toDouble() ??
        21.0285;
    final initialLng =
        _position?.longitude ??
        (widget.trip['startLng'] as num?)?.toDouble() ??
        105.8542;

    return Theme(
      data: SfTheme.dark,
      child: Scaffold(
        backgroundColor: SfColors.darkBg,
        body: Stack(
          children: [
            // Bản đồ mờ dần và thu nhỏ khi bảng chặng kéo lên cao nhất.
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: _sheetSize,
                builder: (context, size, child) {
                  final t = ((size - _snaps[1]) / (_snaps[2] - _snaps[1]))
                      .clamp(0.0, 1.0);
                  return Opacity(
                    opacity: 1 - 0.35 * t,
                    child: Transform.scale(scale: 1 - 0.02 * t, child: child),
                  );
                },
                child: Stack(
                  children: [
                    MapLibreMap(
                      styleString: AppConfig.mapStyleUrlDark,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(initialLat, initialLng),
                        zoom: 15,
                      ),
                      myLocationEnabled: true,
                      myLocationTrackingMode:
                          MyLocationTrackingMode.trackingGps,
                      compassEnabled: false,
                      onMapCreated: (controller) => _map = controller,
                      onStyleLoadedCallback: () {
                        _styleLoaded = true;
                        _drawRoute();
                      },
                    ),
                    if (AppConfig.needsDarkMapOverlay)
                      // Chưa có style tối riêng: phủ lớp lọc để bản đồ sáng
                      // không chói mắt trong cabin ban đêm.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: SfColors.darkBg.withValues(alpha: 0.32),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Thẻ chỉ dẫn + banner ngập, neo trên cùng.
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(SfSpace.x12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _turnCard(),
                    if (_navigation?.safe == false) ...[
                      const SizedBox(height: SfSpace.x10),
                      _floodBanner(),
                    ],
                  ],
                ),
              ),
            ),

            // Chỉ số bên trái: tốc độ và giờ lái liên tục.
            Positioned(left: SfSpace.x14, bottom: 250, child: _metricPills()),

            // Cột phải: một wrapper duy nhất, không neo từng nút riêng.
            Positioned(right: SfSpace.x14, bottom: 250, child: _rightRail()),

            _sheet(),

            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: SfColors.darkBg.withValues(alpha: 0.55),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),

            if (_wakeReady && agent.engaged)
              Positioned.fill(child: AgentChatScreen(onClose: _closeAgent)),
          ],
        ),
      ),
    );
  }

  // ---- Thẻ chỉ dẫn rẽ: thông tin quan trọng nhất màn hình ----

  Widget _turnCard() {
    final navState = _navState;
    final nextStep = navState?.upcomingStep;
    // Distance to the *next turn*, measured on the polyline the vehicle is
    // matched onto - not the length of the whole remaining route.
    final metres = navState?.distanceToManeuverMeters;
    final String value;
    final String unit;
    if (metres == null) {
      value = '--';
      unit = 'm';
    } else if (metres >= 1000) {
      value = (metres / 1000).toStringAsFixed(1).replaceAll('.', ',');
      unit = 'km';
    } else {
      value = (metres / 5).round() * 5 == 0
          ? '0'
          : ((metres / 5).round() * 5).toString();
      unit = 'm';
    }

    return Container(
      padding: const EdgeInsets.all(SfSpace.x16),
      decoration: BoxDecoration(
        color: SfColors.green700.withValues(alpha: 0.94),
        borderRadius: SfRadius.heroR,
        boxShadow: SfShadow.dock,
      ),
      child: Row(
        children: [
          Icon(
            bannerManeuver(nextStep).icon,
            size: 44,
            color: SfColors.onAccent,
          ),
          const SizedBox(width: SfSpace.x14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: SfType.displayDrive.copyWith(
                        color: SfColors.onAccent,
                      ),
                    ),
                    const SizedBox(width: SfSpace.x4),
                    Text(
                      unit,
                      style: SfType.titleCardSm.copyWith(
                        color: SfColors.green300,
                        fontSize: SfTouch.driveFontFloor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  navState == null
                      ? 'Đang chuẩn bị chỉ dẫn'
                      : navState.offRoute
                      ? 'Đã đi lệch tuyến — quay lại đường màu xanh'
                      : bannerInstruction(nextStep),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.titleCard.copyWith(
                    color: SfColors.onAccent,
                    fontSize: SfTouch.driveFontFloor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SfSpace.x8),
          SfIconButton(
            icon: Icons.close_rounded,
            size: SfTouch.iconBtnLg,
            onHero: true,
            tooltip: 'Thoát chế độ lái',
            onTap: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }

  // ---- Banner ngập trên tuyến ----

  Widget _floodBanner() {
    final session = _navigation;
    final warnings = session == null || session.isEmpty
        ? const <String>[]
        : session.selected.warnings;
    return Container(
      padding: const EdgeInsets.all(SfSpace.x14),
      decoration: BoxDecoration(
        color: SfColors.danger.withValues(alpha: 0.95),
        borderRadius: SfRadius.cardSmR,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.water_drop_rounded,
            size: 26,
            color: SfColors.onDanger,
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  warnings.isEmpty ? 'Có điểm ngập trên tuyến' : warnings.first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.titleCardSm.copyWith(
                    color: SfColors.onDanger,
                    fontSize: SfTouch.driveFontFloor,
                  ),
                ),
                if (warnings.length > 1) ...[
                  const SizedBox(height: 2),
                  Text(
                    warnings[1],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SfType.caption.copyWith(
                      color: SfColors.onDanger.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          // Nhãn không được ngắt dòng.
          SfPressable(
            onTap: _busy ? null : _rerouteAroundFlood,
            child: Container(
              height: SfTouch.min,
              padding: const EdgeInsets.symmetric(horizontal: SfSpace.x16),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: SfColors.onDanger,
                borderRadius: SfRadius.controlR,
              ),
              child: Text(
                'Đi vòng',
                softWrap: false,
                overflow: TextOverflow.visible,
                style: SfType.titleCardSm.copyWith(color: SfColors.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rerouteAroundFlood() async {
    final position = _position;
    if (position == null) return;
    await _requestRoute(position);
  }

  // ---- Chỉ số bên trái ----

  Widget _metricPills() {
    final speed = ((_position?.speed ?? 0) * 3.6).round();
    final continuous = _continuousMinutes;
    final overThreshold = continuous >= 180;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill(
          icon: Icons.speed_rounded,
          text: '$speed km/h',
          iconColor: SfColors.green400,
        ),
        const SizedBox(height: SfSpace.x10),
        _pill(
          icon: Icons.timer_rounded,
          text:
              '${continuous ~/ 60}h${(continuous % 60).toString().padLeft(2, '0')}'
              ' liên tục',
          iconColor: overThreshold ? SfColors.amber : SfColors.green400,
        ),
      ],
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required Color iconColor,
  }) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: SfSpace.x12,
      vertical: SfSpace.x10,
    ),
    decoration: BoxDecoration(
      color: SfColors.darkBg.withValues(alpha: 0.86),
      borderRadius: SfRadius.pillR,
      border: Border.all(color: SfColors.darkBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: SfSpace.x8),
        Text(
          text,
          style: SfType.mono.copyWith(
            color: SfColors.darkTextPrimary,
            fontSize: SfTouch.driveFontFloor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  // ---- Cột phải: trạng thái tỉnh táo + trạng thái kết nối ----

  Widget _rightRail() {
    final cabin = ref.watch(cabinSafetyProvider);
    final metrics = cabin.metrics;
    final ready = cabin.active && metrics?.calibrated == true;
    final riskLevel = ready ? drowsinessRiskLevel(metrics!.score) : null;
    final riskColor = switch (riskLevel) {
      null => SfColors.darkTextMuted,
      <= 3 => SfColors.green400,
      <= 5 => SfColors.amber,
      _ => SfColors.danger,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill(
          icon: Icons.gps_fixed_rounded,
          text: _gps,
          iconColor: switch (_gps) {
            'GPS tốt' => SfColors.green400,
            'GPS yếu' => SfColors.amber,
            'Mất GPS' => SfColors.danger,
            _ => SfColors.darkTextMuted,
          },
        ),
        const SizedBox(height: SfSpace.x10),
        _pill(
          icon: _online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          text: _online
              ? (_queueCount == 0 ? 'Đã đồng bộ' : '$_queueCount chờ')
              : 'Ngoại tuyến',
          iconColor: _online ? SfColors.green400 : SfColors.amber,
        ),
        const SizedBox(height: SfSpace.x10),
        SfPressable(
          onTap: () => Navigator.push<void>(
            context,
            SfSlideRoute<void>(builder: (_) => const CabinCameraScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SfSpace.x12,
              vertical: SfSpace.x10,
            ),
            decoration: BoxDecoration(
              color: SfColors.darkBg.withValues(alpha: 0.86),
              borderRadius: SfRadius.pillR,
              border: Border.all(color: riskColor.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cabin.active
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  size: 20,
                  color: riskColor,
                ),
                const SizedBox(width: SfSpace.x8),
                Text(
                  riskLevel == null
                      ? (cabin.enabled ? 'Đang hiệu chỉnh' : 'AI tắt')
                      : drowsinessRiskLabel(riskLevel),
                  style: SfType.titleCardSm.copyWith(
                    color: riskColor,
                    fontSize: SfTouch.driveFontFloor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- Bảng chặng 3 mức ----

  Widget _sheet() {
    final session = _navigation;
    final selected = session == null || session.isEmpty ? null : session.selected;
    final navState = _navState;
    final steps = selected?.steps ?? const <NavStep>[];
    // Once guidance is running these come from live progress rather than from
    // the figures the route was planned with.
    final remaining =
        navState?.remainingDuration ??
        Duration(seconds: (selected?.reportedDurationSeconds ?? 0).round());
    final durationMinutes = remaining.inSeconds / 60;
    final distanceKm =
        (navState?.remainingMeters ?? selected?.lengthMeters ?? 0) / 1000;
    final eta = navState?.eta ?? DateTime.now().add(remaining);

    return SfSheet(
      controller: _sheetController,
      snaps: _snaps,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          SfSpace.x16,
          0,
          SfSpace.x16,
          SfSpace.x24,
        ),
        children: [
          Text(
            '${eta.hour.toString().padLeft(2, '0')}:'
            '${eta.minute.toString().padLeft(2, '0')} đến nơi',
            style: SfType.titleSub.copyWith(
              color: SfColors.darkTextPrimary,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: SfSpace.x4),
          Text(
            '${distanceKm.toStringAsFixed(1)} km · '
            '${durationMinutes.ceil()} phút · '
            '${widget.trip['endLocation'] ?? 'điểm đến'}',
            style: SfType.bodySm.copyWith(
              color: _navigation?.safe == false
                  ? SfColors.amber
                  : SfColors.darkTextMuted,
              fontSize: SfTouch.driveFontFloor,
            ),
          ),
          const SizedBox(height: SfSpace.x20),
          _actions(),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: SfSpace.x24),
            const SfSectionLabel('Các chặng phía trước'),
            const SizedBox(height: SfSpace.x12),
            SfTimeline(
              entries: [
                // Only the steps still ahead: a driver does not need the turn
                // they took ten minutes ago.
                for (final step in steps
                    .skip(navState == null ? 0 : navState.legIndex)
                    .take(12))
                  SfTimelineEntry(
                    title: bannerInstruction(step),
                    subtitle: formatDistance(step.lengthMeters),
                    color: SfColors.green400,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actions() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: SfDriveAction(
              label: _paused ? 'Tiếp tục' : 'Tạm nghỉ',
              icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              onPressed: _busy ? null : _togglePause,
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: SfDriveAction(
              label: 'Hoàn thành',
              icon: Icons.flag_rounded,
              onPressed: _busy ? null : _complete,
            ),
          ),
        ],
      ),
      const SizedBox(height: SfSpace.x12),
      Row(
        children: [
          Expanded(
            child: SfDriveAction(
              label: 'Báo đường',
              icon: Icons.add_road_rounded,
              onPressed: () => Navigator.push(
                context,
                SfSlideRoute<void>(builder: (_) => const FloodReportScreen()),
              ),
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: SfDriveAction(
              label: 'SOS',
              icon: Icons.sos_rounded,
              tone: SfColors.danger,
              onPressed: () => Navigator.push(
                context,
                SfSlideRoute<void>(builder: (_) => const SosScreen()),
              ),
            ),
          ),
        ],
      ),
    ],
  );



}
