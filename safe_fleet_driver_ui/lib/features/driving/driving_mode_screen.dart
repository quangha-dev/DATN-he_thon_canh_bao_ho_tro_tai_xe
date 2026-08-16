import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../app.dart';
import '../../core/config/app_config.dart';
import '../../core/ai/cabin_safety_provider.dart';
import '../../core/ai/stgt_drowsiness_engine.dart';
import '../../core/ai/temporal_safety_engine.dart';
import '../../core/widgets/ui.dart';
import '../../models/driver_models.dart';
import '../flood/flood_report_screen.dart';
import '../incidents/sos_screen.dart';

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
  NavigationRoute? _navigation;
  Position? _position;
  String _gps = 'Đang định vị';
  bool _online = true;
  int _queueCount = 0;
  bool _paused = false;
  bool _busy = true;
  bool _styleLoaded = false;
  DateTime? _lastTelemetry;

  final _sheetController = DraggableScrollableController();
  final _sheetSize = ValueNotifier<double>(_snaps.first);

  static const _snaps = [0.24, 0.55, 0.92];

  int get tripId => (widget.trip['id'] as num).toInt();
  int get vehicleId => (widget.trip['vehicleId'] as num).toInt();
  int get driverId => (widget.trip['driverId'] as num).toInt();

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(cabinSafetyProvider.notifier).start());
    _sheetController.addListener(_onSheetMoved);
    _initialize();
  }

  @override
  void dispose() {
    unawaited(ref.read(cabinSafetyProvider.notifier).stop());
    _sheetController.removeListener(_onSheetMoved);
    _sheetController.dispose();
    _sheetSize.dispose();
    _positionSubscription?.cancel();
    super.dispose();
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
    if (mounted) {
      setState(() => _navigation = route);
      await _drawRoute();
    }
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
    if (_paused || _navigation == null) return;
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
    final distance = _distanceToSelectedRoute(position);
    try {
      final event = await ref
          .read(driverRepositoryProvider)
          .navigationEvent(
            sessionId: _navigation!.sessionId,
            position: position,
            distanceToRouteMeters: distance,
          );
      if (event['rerouteRequired'] == true) {
        final rerouted = await ref
            .read(driverRepositoryProvider)
            .reroute(sessionId: _navigation!.sessionId, position: position);
        if (mounted) {
          setState(() => _navigation = rerouted);
          await _drawRoute();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _online = false);
    }
  }

  Future<void> _drawRoute() async {
    if (_map == null || !_styleLoaded || _navigation == null) return;
    await _map!.clearLines();
    for (var index = 0; index < _navigation!.routes.length; index++) {
      final candidate = _navigation!.routes[index];
      final geometry = (candidate['geometry'] as List? ?? const []).map((
        point,
      ) {
        final values = point as List;
        return LatLng(
          (values[1] as num).toDouble(),
          (values[0] as num).toDouble(),
        );
      }).toList();
      if (geometry.length < 2) continue;
      final selected = index == _navigation!.selectedRouteIndex;
      await _map!.addLine(
        LineOptions(
          geometry: geometry,
          // Trên nền tối, tuyến đang chạy dùng mint; các phương án khác lùi
          // hẳn về màu chữ mờ để không tranh chấp thị giác.
          lineColor: selected
              ? sfHex(SfColors.mint)
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

            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(SfSpace.x12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _turnCard(),
                    const SizedBox(height: SfSpace.x8),
                    _statusRow(),
                  ],
                ),
              ),
            ),

            _sheet(),

            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: SfColors.darkBg.withValues(alpha: 0.55),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---- Bảng chỉ dẫn rẽ: thông tin quan trọng nhất màn hình ----

  Widget _turnCard() {
    final selected = _navigation?.routes.isNotEmpty == true
        ? _navigation!.selected
        : null;
    final steps = selected?['steps'] as List?;
    final nextStep = steps?.isNotEmpty == true
        ? Map<String, dynamic>.from(steps!.first as Map)
        : null;
    final metres = (nextStep?['distanceMeters'] as num?)?.toDouble();
    final String value;
    final String unit;
    if (metres == null) {
      value = '--';
      unit = 'm';
    } else if (metres >= 1000) {
      value = (metres / 1000).toStringAsFixed(1);
      unit = 'km';
    } else {
      value = metres.round().toString();
      unit = 'm';
    }

    return Container(
      padding: const EdgeInsets.all(SfSpace.x16),
      decoration: BoxDecoration(
        color: SfColors.darkSurface,
        borderRadius: SfRadius.cardR,
        border: Border.all(color: SfColors.darkBorder),
        boxShadow: SfShadow.floating,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: SfTouch.drive,
            height: SfTouch.drive,
            child: Material(
              color: SfColors.darkSurfaceAlt,
              borderRadius: SfRadius.controlR,
              child: InkWell(
                borderRadius: SfRadius.controlR,
                onTap: () => Navigator.maybePop(context),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: SfColors.darkTextPrimary,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: SfSpace.x16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      _turnIcon(nextStep?['maneuver']?.toString()),
                      size: 26,
                      color: SfColors.mint,
                    ),
                    const SizedBox(width: SfSpace.x8),
                    Text(
                      value,
                      style: SfType.displayDrive.copyWith(
                        color: SfColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(width: SfSpace.x4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: SfSpace.x8),
                      child: Text(
                        unit,
                        style: SfType.titleCard.copyWith(
                          color: SfColors.darkTextSecondary,
                          fontSize: SfTouch.driveFontFloor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  nextStep?['instruction']?.toString() ??
                      'Đang chuẩn bị chỉ dẫn',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.body.copyWith(
                    color: SfColors.darkTextPrimary,
                    fontSize: SfTouch.driveFontFloor + 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow() => Row(
    children: [
      SfStatusPill(
        _gps,
        status: switch (_gps) {
          'GPS tốt' => SfStatus.good,
          'GPS yếu' => SfStatus.warning,
          'Mất GPS' => SfStatus.danger,
          _ => SfStatus.pending,
        },
        icon: Icons.gps_fixed_rounded,
        dense: true,
      ),
      const SizedBox(width: SfSpace.x8),
      SfConnectionChip(online: _online, pendingCount: _queueCount),
    ],
  );

  // ---- Bảng chặng 3 mức ----

  Widget _sheet() {
    final cabin = ref.watch(cabinSafetyProvider);
    final selected = _navigation?.routes.isNotEmpty == true
        ? _navigation!.selected
        : null;
    final steps = (selected?['steps'] as List? ?? const [])
        .whereType<Map>()
        .map((step) => Map<String, dynamic>.from(step))
        .toList();
    final durationMinutes =
        ((selected?['durationSeconds'] as num?)?.toDouble() ?? 0) / 60;
    final distanceKm =
        ((selected?['distanceMeters'] as num?)?.toDouble() ?? 0) / 1000;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SfMetric(
                label: 'Tốc độ',
                value: '${((_position?.speed ?? 0) * 3.6).round()}',
                unit: 'km/h',
                drive: true,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'CÒN LẠI',
                    style: SfType.label.copyWith(
                      color: SfColors.darkTextSecondary,
                      fontSize: SfTouch.driveFontFloor,
                    ),
                  ),
                  const SizedBox(height: SfSpace.x4),
                  Text(
                    '${distanceKm.toStringAsFixed(1)} km',
                    style: SfType.titleScreen.copyWith(
                      color: SfColors.darkTextPrimary,
                    ),
                  ),
                  Text(
                    '${durationMinutes.ceil()} phút · ${_navigation?.safe == true ? 'tuyến an toàn' : 'còn rủi ro ngập'}',
                    style: SfType.body.copyWith(
                      color: _navigation?.safe == true
                          ? SfColors.darkTextSecondary
                          : SfColors.amber,
                      fontSize: SfTouch.driveFontFloor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x20),
          _cabinRow(cabin),
          const SizedBox(height: SfSpace.x20),
          _actions(),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: SfSpace.x24),
            const SfSectionLabel('Các chặng phía trước'),
            const SizedBox(height: SfSpace.x12),
            SfTimeline(
              entries: [
                for (final step in steps.take(12))
                  SfTimelineEntry(
                    title: step['instruction']?.toString() ?? '--',
                    meta: _stepDistance(step['distanceMeters']),
                    status: SfStatus.pending,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cabinRow(CabinSafetyState cabin) {
    final metrics = cabin.metrics;
    final ready = cabin.active && metrics?.calibrated == true;
    final riskLevel = ready ? drowsinessRiskLevel(metrics!.score) : null;
    final predictedLevel = ready
        ? drowsinessRiskLevel(metrics!.predictedScore)
        : null;
    final riskColor = switch (riskLevel) {
      null => SfColors.darkTextSecondary,
      <= 3 => SfColors.mint,
      <= 5 => SfColors.amber,
      _ => SfColors.danger,
    };

    return Container(
      padding: const EdgeInsets.all(SfSpace.x16),
      decoration: BoxDecoration(
        color: SfColors.darkSurfaceAlt,
        borderRadius: SfRadius.controlR,
        border: Border.all(color: riskColor.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(
            cabin.active
                ? Icons.visibility_rounded
                : Icons.visibility_off_outlined,
            size: 26,
            color: cabin.active ? riskColor : SfColors.darkTextSecondary,
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nguy cơ buồn ngủ',
                  style: SfType.titleCard.copyWith(
                    color: SfColors.darkTextPrimary,
                    fontSize: SfTouch.driveFontFloor,
                  ),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  riskLevel == null
                      ? (cabin.enabled ? cabin.message : 'Đang tắt')
                      : '${drowsinessRiskLabel(riskLevel)} · ${metrics!.statusText}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.body.copyWith(
                    color: riskColor,
                    fontSize: SfTouch.driveFontFloor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  '${cabin.modelMode.label.toUpperCase()} · NGƯỠNG 1–10',
                  style: SfType.label.copyWith(color: SfColors.darkTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          Container(
            width: 92,
            padding: const EdgeInsets.symmetric(
              horizontal: SfSpace.x8,
              vertical: SfSpace.x8,
            ),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.12),
              borderRadius: SfRadius.controlR,
            ),
            child: Column(
              children: [
                Text(
                  riskLevel?.toString() ?? '--',
                  style: SfType.displayDrive.copyWith(
                    color: riskColor,
                    fontSize: 34,
                  ),
                ),
                Text(
                  '/10 hiện tại',
                  style: SfType.label.copyWith(
                    color: SfColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  predictedLevel == null
                      ? 'Dự báo --'
                      : 'Dự báo $predictedLevel/10',
                  style: SfType.label.copyWith(color: riskColor),
                ),
              ],
            ),
          ),
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
              label: 'Báo ngập',
              icon: Icons.water_drop_rounded,
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

  // ---- Tiện ích ----

  String _stepDistance(Object? metres) {
    final value = (metres as num?)?.toDouble();
    if (value == null) return '--';
    return value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)} km'
        : '${value.round()} m';
  }

  IconData _turnIcon(String? maneuver) {
    final value = maneuver?.toLowerCase() ?? '';
    if (value.contains('left')) return Icons.turn_left_rounded;
    if (value.contains('right')) return Icons.turn_right_rounded;
    if (value.contains('roundabout')) return Icons.roundabout_left_rounded;
    if (value.contains('arrive')) return Icons.flag_rounded;
    return Icons.straight_rounded;
  }

  double _distanceToSelectedRoute(Position position) {
    if (_navigation == null || _navigation!.routes.isEmpty) return 0;
    final geometry = _navigation!.selected['geometry'] as List? ?? const [];
    if (geometry.isEmpty) return 0;
    var minimum = double.infinity;
    for (final raw in geometry) {
      final point = raw as List;
      final lat = (point[1] as num).toDouble();
      final lng = (point[0] as num).toDouble();
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );
      minimum = math.min(minimum, distance);
    }
    return minimum.isFinite ? minimum : 0;
  }
}
