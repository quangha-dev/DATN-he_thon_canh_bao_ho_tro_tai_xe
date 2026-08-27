import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../app.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/ui.dart';
import '../../models/driver_models.dart';
import '../flood/flood_report_screen.dart';
import 'engine/nav_route.dart';
import 'engine/navigation_engine.dart';
import 'route_offline_map_cache.dart';
import 'turn_by_turn_screen.dart';

enum _SearchTarget { origin, destination }

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({
    super.key,
    this.initialDestination,
    this.autoStart = false,
  });

  final LocationPoint? initialDestination;
  final bool autoStart;

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final _originText = TextEditingController();
  final _destinationText = TextEditingController();
  final _originFocus = FocusNode();
  final _destinationFocus = FocusNode();
  MapLibreMapController? _map;
  Timer? _searchDebounce;
  LocationPoint? _origin;
  LocationPoint? _destination;
  List<LocationPoint> _suggestions = const [];
  List<Map<String, dynamic>> _floodPoints = const [];
  NavSession? _navigation;
  _SearchTarget _searchTarget = _SearchTarget.destination;
  _MapFilter _filter = _MapFilter.all;
  bool _styleReady = false;
  Future<void>? _hazardMarkerImagesFuture;
  bool _locating = true;
  bool _routing = false;
  bool _autoGuidanceLaunched = false;
  bool _openingGuidance = false;
  /// Điểm tài xế vừa chạm giữ trên bản đồ, chưa quyết định là đi hay đến.
  LocationPoint? _pin;
  bool _naming = false;
  bool? _offlineMapReady;
  double _offlineMapProgress = 0;
  Future<bool>? _offlineMapFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialDestination != null) {
      _destination = widget.initialDestination;
      _destinationText.text = widget.initialDestination!.name;
    }
    unawaited(_useCurrentLocation());
    if (widget.initialDestination == null) {
      unawaited(_restoreCachedNavigation());
    }
  }

  Future<void> _restoreCachedNavigation() async {
    final navigation = await ref
        .read(driverRepositoryProvider)
        .currentNavigation();
    if (!mounted || navigation == null || navigation.isEmpty) return;
    final destination = navigation.destination;
    setState(() {
      _navigation = navigation;
      if (destination != null) {
        _destination = LocationPoint(
          name: navigation.destinationName ?? 'Điểm đến đã lưu',
          address: '${destination.latitude.toStringAsFixed(5)}, '
              '${destination.longitude.toStringAsFixed(5)}',
          lat: destination.latitude,
          lng: destination.longitude,
          source: 'OFFLINE_CACHE',
        );
        _destinationText.text = _destination!.name;
      }
    });
    await _drawMap();
    await _fitSelectedRoute();
    unawaited(_ensureOfflineMap(navigation));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _originText.dispose();
    _destinationText.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Cần quyền vị trí để chọn điểm xuất phát');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final point = LocationPoint(
        name: 'Vị trí hiện tại',
        address:
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}',
        lat: position.latitude,
        lng: position.longitude,
        source: 'DEVICE_GPS',
      );
      if (!mounted) return;
      setState(() {
        _origin = point;
        _originText.text = point.name;
      });
      await _map?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(point.lat, point.lng), 14),
      );
      await _loadFloodPoints(point.lat, point.lng);
      await _drawMap();
      if (widget.autoStart && _destination != null) {
        await _findRoute();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onSearchChanged(String value, _SearchTarget target) {
    _searchDebounce?.cancel();
    setState(() {
      _searchTarget = target;
      if (value.trim().length < 2) _suggestions = const [];
    });
    if (value.trim().length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await ref
            .read(driverRepositoryProvider)
            .autocompleteLocation(value.trim());
        if (mounted && _searchTarget == target) {
          setState(() => _suggestions = results);
        }
      } catch (error) {
        if (mounted) setState(() => _error = error.toString());
      }
    });
  }

  Future<void> _selectLocation(LocationPoint point) async {
    setState(() {
      if (_searchTarget == _SearchTarget.origin) {
        _origin = point;
        _originText.text = point.name;
      } else {
        _destination = point;
        _destinationText.text = point.name;
      }
      _suggestions = const [];
      _error = null;
    });
    _originFocus.unfocus();
    _destinationFocus.unfocus();
    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(point.lat, point.lng), 14),
    );
    await _drawMap();
  }

  Future<void> _findRoute() async {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null || _routing) return;
    setState(() {
      _routing = true;
      _error = null;
    });
    try {
      final route = await ref
          .read(driverRepositoryProvider)
          .navigationRoute(
            originLat: origin.lat,
            originLng: origin.lng,
            destinationLat: destination.lat,
            destinationLng: destination.lng,
            destinationName: destination.name,
          );
      final centerLat = (origin.lat + destination.lat) / 2;
      final centerLng = (origin.lng + destination.lng) / 2;
      await _loadFloodPoints(centerLat, centerLng);
      if (!mounted) return;
      setState(() {
        _navigation = route;
        _offlineMapReady = null;
        _offlineMapProgress = 0;
        _offlineMapFuture = null;
      });
      await _drawMap();
      await _fitSelectedRoute();
      unawaited(_ensureOfflineMap(route));
      if (widget.autoStart && !_autoGuidanceLaunched) {
        _autoGuidanceLaunched = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_openGuidance());
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<void> _loadFloodPoints(double lat, double lng) async {
    try {
      final points = await ref
          .read(driverRepositoryProvider)
          .nearbyFloodPoints(lat: lat, lng: lng);
      if (mounted) setState(() => _floodPoints = points);
    } catch (_) {
      // Route vẫn dùng được vì backend chấm điểm trực tiếp từ PostgreSQL.
    }
  }

  /// Cắm hoặc dời ghim, rồi hỏi geocoder xem chỗ đó tên gì.
  Future<void> _dropPin(LatLng coordinates) async {
    setState(() {
      _pin = LocationPoint(
        name: 'Đang xác định vị trí…',
        address:
            '${coordinates.latitude.toStringAsFixed(5)}, '
            '${coordinates.longitude.toStringAsFixed(5)}',
        lat: coordinates.latitude,
        lng: coordinates.longitude,
        source: 'MAP_PIN',
      );
      _naming = true;
      _suggestions = const [];
      _error = null;
    });
    _originFocus.unfocus();
    _destinationFocus.unfocus();
    await _drawMap();

    final named = await ref
        .read(driverRepositoryProvider)
        .reverseGeocode(lat: coordinates.latitude, lng: coordinates.longitude);
    if (!mounted) return;
    // Tài xế có thể đã dời ghim trong lúc chờ tên trả về.
    final current = _pin;
    if (current == null ||
        current.lat != coordinates.latitude ||
        current.lng != coordinates.longitude) {
      return;
    }
    setState(() {
      _pin = named;
      _naming = false;
    });
  }

  Future<void> _usePin({required bool asDestination}) async {
    final pin = _pin;
    if (pin == null) return;
    setState(() {
      if (asDestination) {
        _destination = pin;
        _destinationText.text = pin.name;
      } else {
        _origin = pin;
        _originText.text = pin.name;
      }
      _pin = null;
      _naming = false;
      _navigation = null;
    });
    await _loadFloodPoints(pin.lat, pin.lng);
    await _drawMap();
  }

  void _clearPin() {
    setState(() {
      _pin = null;
      _naming = false;
    });
    unawaited(_drawMap());
  }

  Future<void> _openRoadHazardReport() async {
    await Navigator.push<void>(
      context,
      SfSlideRoute<void>(builder: (_) => const FloodReportScreen()),
    );
    if (!mounted) return;
    final center = _origin ?? _destination;
    if (center == null) return;
    await _loadFloodPoints(center.lat, center.lng);
    await _drawMap();
  }

  Future<void> _openGuidance() async {
    final session = _navigation;
    final destination = _destination;
    if (session == null || destination == null || session.isEmpty) return;

    setState(() => _openingGuidance = true);
    final ready = await _ensureOfflineMap(session);
    if (!mounted) return;
    setState(() => _openingGuidance = false);
    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa tải đủ nền bản đồ. Tuyến, bước rẽ và giọng nói vẫn chạy offline.',
          ),
        ),
      );
    }
    await Navigator.of(context).push<void>(
      SfDriveRoute<void>(
        builder: (_) =>
            TurnByTurnScreen(session: session, destination: destination),
      ),
    );
    if (!mounted) return;
    // Guidance owns the session once it starts; coming back means it ended.
    setState(() => _navigation = null);
    await _drawMap();
  }

  Future<bool> _ensureOfflineMap(NavSession route) {
    final existing = _offlineMapFuture;
    if (existing != null) return existing;
    final future = RouteOfflineMapCache.ensure(
      route,
      onProgress: (progress) {
        if (mounted) setState(() => _offlineMapProgress = progress);
      },
    );
    _offlineMapFuture = future;
    future.then((ready) {
      if (mounted) {
        setState(() {
          _offlineMapReady = ready;
          if (ready) _offlineMapProgress = 1;
        });
      }
    });
    return future;
  }

  Future<void> _drawMap() async {
    final map = _map;
    if (map == null || !_styleReady) return;
    await map.clearLines();
    await map.clearCircles();
    await map.clearSymbols();
    await _ensureHazardMarkerImages(map);

    final routes = _navigation?.routes ?? const <NavRoute>[];
    // Unselected alternatives are drawn first so the chosen route always wins
    // the overlap where two options share a street.
    for (var index = routes.length - 1; index >= 0; index--) {
      final candidate = routes[index];
      if (candidate.geometry.length < 2) continue;
      final selected = index == _navigation!.selectedIndex;
      if (selected) continue;
      await map.addLine(
        LineOptions(
          geometry: candidate.geometry,
          lineColor: sfHex(SfColors.textTertiary),
          lineWidth: 4,
          lineOpacity: .45,
        ),
      );
    }
    if (routes.isNotEmpty) {
      final candidate = _navigation!.selected;
      await map.addLine(
        LineOptions(
          geometry: candidate.geometry,
          lineColor: candidate.safe
              ? sfHex(SfColors.green700)
              : sfHex(SfColors.amber),
          lineWidth: 6,
          lineOpacity: .96,
        ),
      );
    }

    // Chip lọc quyết định lớp tình trạng đường nào được vẽ.
    final visibleHazards = _floodPoints.where((point) {
      final type = point['hazardType']?.toString() ?? 'FLOOD';
      return _filter == _MapFilter.all ||
          (_filter == _MapFilter.flood && type == 'FLOOD') ||
          (_filter == _MapFilter.trafficJam && type == 'TRAFFIC_JAM');
    });
    for (final hazard in visibleHazards) {
      final lat = (hazard['lat'] as num?)?.toDouble();
      final lng = (hazard['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final severity = hazard['severity']?.toString();
      final trafficJam = hazard['hazardType']?.toString() == 'TRAFFIC_JAM';
      await map.addSymbol(
        SymbolOptions(
          geometry: LatLng(lat, lng),
          iconImage: trafficJam ? 'safefleet-traffic-jam' : 'safefleet-flood',
          iconSize: severity == 'BLOCKED' ? .72 : .62,
        ),
      );
    }

    final pin = _pin;
    if (pin != null) {
      await map.addCircle(
        CircleOptions(
          geometry: LatLng(pin.lat, pin.lng),
          circleRadius: 10,
          circleColor: sfHex(SfColors.amber),
          circleStrokeColor: sfHex(SfColors.surface),
          circleStrokeWidth: 3,
        ),
      );
    }

    for (final marker in [_origin, _destination]) {
      if (marker == null) continue;
      await map.addCircle(
        CircleOptions(
          geometry: LatLng(marker.lat, marker.lng),
          circleRadius: 7,
          circleColor: marker == _origin
              ? sfHex(SfColors.info)
              : sfHex(SfColors.green700),
          circleStrokeColor: sfHex(SfColors.surface),
          circleStrokeWidth: 3,
        ),
      );
    }
  }

  Future<void> _ensureHazardMarkerImages(MapLibreMapController map) {
    return _hazardMarkerImagesFuture ??= () async {
      await map.addImage(
        'safefleet-flood',
        await _hazardMarkerBytes(Icons.water_drop_rounded, SfColors.info),
      );
      await map.addImage(
        'safefleet-traffic-jam',
        await _hazardMarkerBytes(
          Icons.directions_car_filled_rounded,
          SfColors.warning,
        ),
      );
    }();
  }

  Future<Uint8List> _hazardMarkerBytes(IconData icon, Color color) async {
    const size = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);
    canvas.drawCircle(
      center,
      43,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      38,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 45,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );
    final image = await recorder.endRecording().toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Không thể tạo icon bản đồ');
    return data.buffer.asUint8List();
  }

  Future<void> _fitSelectedRoute() async {
    final navigation = _navigation;
    final map = _map;
    if (navigation == null || map == null || navigation.isEmpty) return;
    final geometry = navigation.selected.geometry;
    if (geometry.length < 2) return;
    var minLat = geometry.first.latitude;
    var maxLat = minLat;
    var minLng = geometry.first.longitude;
    var maxLng = minLng;
    for (final point in geometry.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    await map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 40,
        top: 180,
        right: 40,
        bottom: 260,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          // Bản đồ toàn màn — lớp dưới cùng.
          MapLibreMap(
            styleString: AppConfig.mapStyleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(21.0285, 105.8542),
              zoom: 12.5,
            ),
            myLocationEnabled: true,
            compassEnabled: false,
            // Chạm giữ để cắm ghim: rất nhiều điểm giao nhận ở Việt Nam là
            // kho, bãi hoặc cổng sau không có địa chỉ tra cứu được.
            onMapLongClick: (_, coordinates) => unawaited(_dropPin(coordinates)),
            onMapCreated: (controller) => _map = controller,
            onStyleLoadedCallback: () {
              _styleReady = true;
              _hazardMarkerImagesFuture = null;
              unawaited(_drawMap());
            },
          ),

          // Lớp phủ trên cùng: ô tìm kiếm + chip lọc.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SfSpace.x16,
                SfSpace.x12,
                SfSpace.x16,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _searchBar(p),
                  if (_suggestions.isNotEmpty) _suggestionPanel(p),
                  if (_error != null) _errorPanel(p),
                  const SizedBox(height: SfSpace.x10),
                  _filterRow(),
                ],
              ),
            ),
          ),

          // Cụm nút phải: vị trí của tôi, lớp bản đồ.
          Positioned(
            right: SfSpace.x14,
            bottom: _navigation == null ? 150 : 300,
            child: Column(
              children: [
                SfIconButton(
                  icon: Icons.my_location_rounded,
                  size: SfTouch.iconBtnLg,
                  tooltip: 'Vị trí của tôi',
                  onTap: _locating ? null : _useCurrentLocation,
                ),
                const SizedBox(height: SfSpace.x10),
                SfIconButton(
                  icon: Icons.layers_rounded,
                  size: SfTouch.iconBtnLg,
                  tooltip: 'Lớp bản đồ',
                  onTap: _showLayers,
                ),
              ],
            ),
          ),

          // Bottom sheet: chừa 96px để không chạm dock.
          // Ghim vừa cắm luôn được ưu tiên - đó là thao tác tài xế vừa làm.
          if (_pin != null)
            Positioned(
              left: SfSpace.x16,
              right: SfSpace.x16,
              bottom: 96,
              child: _pinSheet(p),
            )
          else if (_navigation != null)
            Positioned(
              left: SfSpace.x16,
              right: SfSpace.x16,
              bottom: 96,
              child: _routeSheet(p),
            )
          else if (_origin != null && _destination != null)
            Positioned(
              left: SfSpace.x16,
              right: SfSpace.x16,
              bottom: 96,
              child: _findSheet(),
            ),
        ],
      ),
    );
  }

  // ---- Ô tìm kiếm cao 50 + nút báo tình trạng đường ----

  Widget _searchBar(SfPalette p) => Row(
    children: [
      // Bản đồ vừa là tab vừa được push từ Nhà / Trợ lý.
      if (Navigator.canPop(context)) ...[
        SfIconButton(
          icon: Icons.arrow_back_rounded,
          size: 50,
          tooltip: 'Quay lại',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: SfSpace.x10),
      ],
      Expanded(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: SfRadius.controlLgR,
            boxShadow: SfShadow.card,
          ),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: SfSpace.x14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: SfRadius.controlLgR,
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: SfColors.green700,
                ),
                const SizedBox(width: SfSpace.x10),
                Expanded(
                  child: TextField(
                    controller: _destinationText,
                    focusNode: _destinationFocus,
                    onTap: () => setState(
                      () => _searchTarget = _SearchTarget.destination,
                    ),
                    onChanged: (value) =>
                        _onSearchChanged(value, _SearchTarget.destination),
                    style: SfType.bodySm.copyWith(color: p.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Bạn muốn đi đâu?',
                      hintStyle: SfType.bodySm.copyWith(color: p.textMuted),
                    ),
                  ),
                ),
                if (_destinationText.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Xoá',
                    iconSize: 18,
                    color: p.textMuted,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _destinationText.clear();
                      setState(() {
                        _destination = null;
                        _suggestions = const [];
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: SfSpace.x10),
      SfIconButton(
        icon: Icons.add_location_alt_rounded,
        size: 50,
        tooltip: 'Báo ngập hoặc kẹt xe',
        onTap: _openRoadHazardReport,
      ),
    ],
  );

  // ---- Hàng chip lọc ----

  Widget _filterRow() => SizedBox(
    height: 36,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _MapFilter.values.length,
      separatorBuilder: (_, _) => const SizedBox(width: SfSpace.x8),
      itemBuilder: (_, index) {
        final filter = _MapFilter.values[index];
        return SfFilterChip(
          label: filter.label,
          selected: _filter == filter,
          onTap: () {
            setState(() => _filter = filter);
            unawaited(_drawMap());
          },
        );
      },
    ),
  );

  void _showLayers() => showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SfSpace.x16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SfSectionLabel('Lớp bản đồ'),
            const SizedBox(height: SfSpace.x12),
            SfListRow(
              icon: Icons.water_drop_rounded,
              title: 'Điểm ngập',
              subtitle:
                  '${_floodPoints.where((p) => (p['hazardType']?.toString() ?? 'FLOOD') == 'FLOOD').length} điểm đang hoạt động',
              trailing: const SfStatusPill('Đang bật'),
            ),
            const SizedBox(height: SfSpace.x8),
            SfListRow(
              icon: Icons.traffic_rounded,
              title: 'Điểm tắc nghẽn',
              subtitle:
                  '${_floodPoints.where((p) => p['hazardType']?.toString() == 'TRAFFIC_JAM').length} điểm đang hoạt động',
              trailing: const SfStatusPill('Đang bật'),
            ),
            const SizedBox(height: SfSpace.x8),
            SfListRow(
              icon: Icons.alt_route_rounded,
              title: 'Tuyến đề xuất',
              subtitle: '${_navigation?.routes.length ?? 0} phương án',
              trailing: SfStatusPill(
                _navigation == null ? 'Chưa có' : 'Đang bật',
                status: _navigation == null ? SfStatus.pending : SfStatus.good,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ---- Bảng gợi ý địa điểm ----

  Widget _suggestionPanel(SfPalette p) => Container(
    margin: const EdgeInsets.only(top: SfSpace.x8),
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: SfRadius.cardR,
      border: Border.all(color: p.border),
      boxShadow: SfShadow.card,
    ),
    child: ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: SfSpace.x4),
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: p.border),
      itemBuilder: (_, index) {
        final place = _suggestions[index];
        return SfListRow(
          icon: Icons.place_rounded,
          title: place.name,
          subtitle: place.address,
          onTap: () => _selectLocation(place),
        );
      },
    ),
  );

  Widget _errorPanel(SfPalette p) => Padding(
    padding: const EdgeInsets.only(top: SfSpace.x8),
    child: SfInfoBox(
      icon: Icons.info_outline_rounded,
      text: _error!,
      status: SfStatus.danger,
    ),
  );

  // ---- Sheet: chưa tìm tuyến ----

  Widget _findSheet() => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: SfRadius.heroR,
      boxShadow: SfShadow.card,
    ),
    child: SfCard(
      radius: SfRadius.hero,
      padding: const EdgeInsets.all(SfSpace.x16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trip_origin_rounded,
                size: 16,
                color: SfColors.info,
              ),
              const SizedBox(width: SfSpace.x8),
              Expanded(
                child: Text(
                  _origin?.name ?? 'Vị trí hiện tại',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.caption.copyWith(color: context.sf.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x8),
          Text(
            _destination?.name ?? 'Điểm đến',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SfType.titleCard.copyWith(color: context.sf.textPrimary),
          ),
          const SizedBox(height: SfSpace.x4),
          Text(
            _destination?.address ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SfType.caption.copyWith(color: context.sf.textMuted),
          ),
          const SizedBox(height: SfSpace.x14),
          SfPrimaryAction(
            label: _routing ? 'Đang so sánh tuyến' : 'Tìm tuyến tránh ngập',
            icon: Icons.alt_route_rounded,
            busy: _routing,
            onPressed: _findRoute,
          ),
        ],
      ),
    ),
  );

  // ---- Sheet: ghim vừa cắm trên bản đồ ----

  Widget _pinSheet(SfPalette p) {
    final pin = _pin!;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: SfRadius.heroR,
        boxShadow: SfShadow.card,
      ),
      child: SfCard(
        radius: SfRadius.hero,
        padding: const EdgeInsets.all(SfSpace.x16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.push_pin_rounded,
                  size: 22,
                  color: SfColors.amberInk,
                ),
                const SizedBox(width: SfSpace.x10),
                Expanded(
                  child: Text(
                    pin.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SfType.titleCardSm.copyWith(color: p.textPrimary),
                  ),
                ),
                SfIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Bỏ ghim',
                  onTap: _clearPin,
                ),
              ],
            ),
            const SizedBox(height: SfSpace.x4),
            Text(
              _naming ? 'Đang tra cứu địa chỉ…' : pin.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SfType.caption.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: SfSpace.x4),
            Text(
              'Chạm giữ chỗ khác trên bản đồ để dời ghim.',
              style: SfType.caption.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: SfSpace.x14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => unawaited(_usePin(asDestination: false)),
                    icon: const Icon(Icons.trip_origin_rounded, size: 18),
                    label: const Text('Điểm đi'),
                  ),
                ),
                const SizedBox(width: SfSpace.x10),
                Expanded(
                  child: SfPrimaryAction(
                    label: 'Điểm đến',
                    icon: Icons.flag_rounded,
                    onPressed: () => unawaited(_usePin(asDestination: true)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Sheet: kết quả tuyến ----

  Widget _routeSheet(SfPalette p) {
    final session = _navigation!;
    if (session.isEmpty) return const SizedBox.shrink();
    final route = session.selected;
    final warnings = route.warnings;

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: SfRadius.heroR,
        boxShadow: SfShadow.card,
      ),
      child: SfCard(
        radius: SfRadius.hero,
        padding: const EdgeInsets.all(SfSpace.x16),
        borderColor: route.safe ? null : SfColors.warningBorder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SfStatusPill(
                  route.safe ? 'Tuyến tránh ngập' : 'Tuyến còn rủi ro',
                  status: route.safe ? SfStatus.good : SfStatus.warning,
                  showIcon: true,
                ),
                const SizedBox(width: SfSpace.x8),
                // Without this the driver would read an OSRM fallback route as
                // if the closure list had been applied to it.
                if (route.providerFallback)
                  const SfStatusPill(
                    'Tuyến suy giảm',
                    status: SfStatus.warning,
                    dense: true,
                  ),
                const Spacer(),
                Text(
                  route.provider,
                  style: SfType.caption.copyWith(color: p.textMuted),
                ),
              ],
            ),
            const SizedBox(height: SfSpace.x14),
            Text(
              _destination?.name ?? 'Điểm đến',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SfType.titleCard.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: SfSpace.x4),
            Text(
              '${formatDistance(route.lengthMeters)} · '
              '${formatDuration(Duration(seconds: route.reportedDurationSeconds.round()))} · '
              '${_hazardSummary(route)}',
              style: SfType.caption.copyWith(color: p.textMuted),
            ),
            if (session.routes.length > 1) ...[
              const SizedBox(height: SfSpace.x12),
              _alternativePicker(session, p),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: SfSpace.x12),
              SfInfoBox(
                icon: Icons.water_drop_rounded,
                text: warnings.take(2).join(' · '),
                status: SfStatus.warning,
              ),
            ],
            if (_offlineMapReady != true) ...[
              const SizedBox(height: SfSpace.x12),
              SfInfoBox(
                icon: Icons.offline_pin_rounded,
                text: _offlineMapReady == false
                    ? 'Nền bản đồ chưa tải đủ; tuyến và hướng dẫn giọng nói đã được lưu.'
                    : 'Đang tải bản đồ offline ${(_offlineMapProgress * 100).round()}%',
                status: _offlineMapReady == false
                    ? SfStatus.warning
                    : SfStatus.pending,
              ),
            ],
            const SizedBox(height: SfSpace.x14),
            Row(
              children: [
                Expanded(
                  child: SfPrimaryAction(
                    label: _openingGuidance
                        ? 'Đang chuẩn bị offline'
                        : 'Đi theo tuyến này',
                    icon: Icons.navigation_rounded,
                    busy: _openingGuidance,
                    onPressed: _openGuidance,
                  ),
                ),
                const SizedBox(width: SfSpace.x10),
                SfIconButton(
                  icon: Icons.close_rounded,
                  size: SfTouch.primaryHeight,
                  tooltip: 'Bỏ tuyến',
                  onTap: () {
                    setState(() => _navigation = null);
                    unawaited(_drawMap());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Counts only the hazards actually intersecting this route. The old label
  /// counted every report within 20 km of the midpoint.
  String _hazardSummary(NavRoute route) {
    final onRoute = route.hazardsOnRouteCount;
    if (onRoute == 0) return 'không có điểm ngập trên tuyến';
    return '$onRoute điểm ngập trên tuyến';
  }

  /// Lets the driver take a different option — the backend ranks them, but the
  /// person behind the wheel knows things the road graph does not.
  Widget _alternativePicker(NavSession session, SfPalette p) => SizedBox(
    height: 74,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: session.routes.length,
      separatorBuilder: (_, _) => const SizedBox(width: SfSpace.x8),
      itemBuilder: (context, index) {
        final option = session.routes[index];
        final selected = index == session.selectedIndex;
        return InkWell(
          borderRadius: SfRadius.controlR,
          onTap: selected ? null : () => _selectRoute(index),
          child: Container(
            width: 152,
            padding: const EdgeInsets.symmetric(
              horizontal: SfSpace.x12,
              vertical: SfSpace.x8,
            ),
            decoration: BoxDecoration(
              color: selected ? SfColors.green050 : p.surface,
              borderRadius: SfRadius.controlR,
              border: Border.all(
                color: selected ? SfColors.green700 : p.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${formatDuration(Duration(seconds: option.reportedDurationSeconds.round()))}'
                  ' · ${formatDistance(option.lengthMeters)}',
                  style: SfType.bodySm.copyWith(
                    color: p.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  option.hazardsOnRouteCount == 0
                      ? (index == 0 ? 'Ít rủi ro nhất' : 'Tránh được ngập')
                      : '${option.hazardsOnRouteCount} điểm ngập',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.caption.copyWith(
                    color: option.hazardsOnRouteCount == 0
                        ? SfColors.green700
                        : SfColors.warning,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> _selectRoute(int index) async {
    final session = _navigation;
    if (session == null) return;
    setState(() {
      _navigation = session.selectRoute(index);
      _offlineMapReady = null;
      _offlineMapProgress = 0;
      _offlineMapFuture = null;
    });
    await _drawMap();
    await _fitSelectedRoute();
    unawaited(_ensureOfflineMap(_navigation!));
  }
}

/// Bộ lọc điểm hiển thị trên bản đồ an toàn.
enum _MapFilter { all, flood, trafficJam, blackspot, restStop }

extension _MapFilterLabel on _MapFilter {
  String get label => switch (this) {
    _MapFilter.all => 'Tất cả',
    _MapFilter.flood => 'Ngập nước',
    _MapFilter.trafficJam => 'Kẹt xe',
    _MapFilter.blackspot => 'Điểm đen',
    _MapFilter.restStop => 'Trạm nghỉ',
  };
}
