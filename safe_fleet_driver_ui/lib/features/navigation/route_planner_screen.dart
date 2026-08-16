import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../app.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/ui.dart';
import '../../models/driver_models.dart';

enum _SearchTarget { origin, destination }

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

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
  NavigationRoute? _navigation;
  _SearchTarget _searchTarget = _SearchTarget.destination;
  bool _styleReady = false;
  bool _locating = true;
  bool _routing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_useCurrentLocation());
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
      setState(() => _navigation = route);
      await _drawMap();
      await _fitSelectedRoute();
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

  Future<void> _drawMap() async {
    final map = _map;
    if (map == null || !_styleReady) return;
    await map.clearLines();
    await map.clearCircles();

    final routes = _navigation?.routes ?? const <Map<String, dynamic>>[];
    for (var index = 0; index < routes.length; index++) {
      final candidate = routes[index];
      final geometry = _geometry(candidate);
      if (geometry.length < 2) continue;
      final selected = index == _navigation!.selectedRouteIndex;
      final safe = candidate['safe'] == true;
      await map.addLine(
        LineOptions(
          geometry: geometry,
          lineColor: selected
              ? (safe ? sfHex(SfColors.teal) : sfHex(SfColors.amber))
              : sfHex(SfColors.textMuted),
          lineWidth: selected ? 6 : 3,
          lineOpacity: selected ? .95 : .5,
        ),
      );
    }

    for (final flood in _floodPoints) {
      final lat = (flood['lat'] as num?)?.toDouble();
      final lng = (flood['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final severity = flood['severity']?.toString();
      await map.addCircle(
        CircleOptions(
          geometry: LatLng(lat, lng),
          circleRadius: severity == 'BLOCKED' ? 11 : 8,
          circleColor: severity == 'BLOCKED'
              ? sfHex(SfColors.danger)
              : sfHex(SfColors.amber),
          circleStrokeColor: sfHex(SfColors.surface),
          circleStrokeWidth: 2,
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
              ? sfHex(SfColors.navy)
              : sfHex(SfColors.teal),
          circleStrokeColor: sfHex(SfColors.surface),
          circleStrokeWidth: 3,
        ),
      );
    }
  }

  List<LatLng> _geometry(Map<String, dynamic> route) =>
      (route['geometry'] as List? ?? const []).map((raw) {
        final values = raw as List;
        return LatLng(
          (values[1] as num).toDouble(),
          (values[0] as num).toDouble(),
        );
      }).toList();

  Future<void> _fitSelectedRoute() async {
    final navigation = _navigation;
    final map = _map;
    if (navigation == null || map == null || navigation.routes.isEmpty) return;
    final geometry = _geometry(navigation.selected);
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
          MapLibreMap(
            styleString: AppConfig.mapStyleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(21.0285, 105.8542),
              zoom: 12.5,
            ),
            myLocationEnabled: true,
            compassEnabled: true,
            onMapCreated: (controller) => _map = controller,
            onStyleLoadedCallback: () {
              _styleReady = true;
              unawaited(_drawMap());
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SfSpace.x16,
                SfSpace.x12,
                SfSpace.x16,
                0,
              ),
              child: Column(
                children: [
                  _searchPanel(p),
                  if (_suggestions.isNotEmpty) _suggestionPanel(p),
                  if (_error != null) _errorPanel(p),
                ],
              ),
            ),
          ),
          if (_navigation != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(
                  SfSpace.x16,
                  0,
                  SfSpace.x16,
                  SfSpace.x40 + SfSpace.x40 + SfSpace.x16,
                ),
                child: _routeSummary(p),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchPanel(SfPalette p) => Container(
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: SfRadius.cardR,
      border: Border.all(color: p.border),
      boxShadow: SfShadow.floating,
    ),
    padding: const EdgeInsets.all(SfSpace.x16),
    child: Column(
      children: [
        Row(
          children: [
            Icon(Icons.route_rounded, color: p.accent),
            const SizedBox(width: SfSpace.x8),
            Expanded(
              child: Text(
                'Tìm đường tránh ngập',
                style: SfType.titleCard.copyWith(color: p.textPrimary),
              ),
            ),
            IconButton(
              tooltip: 'Dùng vị trí hiện tại',
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ],
        ),
        const SizedBox(height: SfSpace.x12),
        _searchField(
          controller: _originText,
          focusNode: _originFocus,
          target: _SearchTarget.origin,
          icon: Icons.trip_origin,
          hint: 'Điểm xuất phát',
        ),
        const SizedBox(height: SfSpace.x8),
        _searchField(
          controller: _destinationText,
          focusNode: _destinationFocus,
          target: _SearchTarget.destination,
          icon: Icons.location_on_outlined,
          hint: 'Bạn muốn đi đâu?',
        ),
        const SizedBox(height: SfSpace.x12),
        SfPrimaryAction(
          label: _routing ? 'Đang so sánh tuyến' : 'Tìm tuyến phù hợp',
          icon: Icons.alt_route_rounded,
          busy: _routing,
          onPressed: _origin == null || _destination == null
              ? null
              : _findRoute,
        ),
      ],
    ),
  );

  Widget _searchField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required _SearchTarget target,
    required IconData icon,
    required String hint,
  }) => TextField(
    controller: controller,
    focusNode: focusNode,
    onTap: () => setState(() => _searchTarget = target),
    onChanged: (value) => _onSearchChanged(value, target),
    decoration: InputDecoration(
      isDense: true,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Xoá',
              onPressed: () {
                controller.clear();
                setState(() {
                  if (target == _SearchTarget.origin) {
                    _origin = null;
                  } else {
                    _destination = null;
                  }
                  _suggestions = const [];
                });
              },
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
    ),
  );

  Widget _suggestionPanel(SfPalette p) => Container(
    margin: const EdgeInsets.only(top: SfSpace.x8),
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: SfRadius.cardR,
      border: Border.all(color: p.border),
      boxShadow: SfShadow.floating,
    ),
    child: ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: SfSpace.x4),
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: p.border),
      itemBuilder: (_, index) {
        final place = _suggestions[index];
        return ListTile(
          leading: Icon(Icons.place_outlined, color: p.textSecondary),
          title: Text(
            place.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SfType.body.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            place.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SfType.meta.copyWith(color: p.textSecondary),
          ),
          onTap: () => _selectLocation(place),
        );
      },
    ),
  );

  Widget _errorPanel(SfPalette p) => Container(
    margin: const EdgeInsets.only(top: SfSpace.x8),
    padding: const EdgeInsets.all(SfSpace.x12),
    decoration: BoxDecoration(
      color: p.dangerTint,
      borderRadius: SfRadius.controlR,
      border: Border.all(color: SfColors.danger),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: SfColors.danger),
        const SizedBox(width: SfSpace.x8),
        Expanded(
          child: Text(
            _error!,
            maxLines: 3,
            style: SfType.body.copyWith(color: p.textPrimary),
          ),
        ),
      ],
    ),
  );

  Widget _routeSummary(SfPalette p) {
    final route = _navigation!;
    final selected = route.routes.isEmpty ? null : route.selected;
    final distance =
        ((selected?['distanceMeters'] as num?)?.toDouble() ?? 0) / 1000;
    final duration =
        ((selected?['durationSeconds'] as num?)?.toDouble() ?? 0) / 60;
    final warnings = (selected?['warnings'] as List? ?? const [])
        .map((item) => item.toString())
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: SfRadius.cardR,
        border: Border.all(
          color: route.safe ? p.border : SfColors.amber,
        ),
        boxShadow: SfShadow.floating,
      ),
      padding: const EdgeInsets.all(SfSpace.x16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SfStatusPill(
                route.safe ? 'Tuyến tránh ngập' : 'Tuyến còn rủi ro',
                status: route.safe ? SfStatus.good : SfStatus.warning,
                icon: route.safe
                    ? Icons.shield_outlined
                    : Icons.warning_amber_rounded,
                dense: true,
              ),
              const Spacer(),
              Text(
                '${route.routes.length} phương án',
                style: SfType.meta.copyWith(color: p.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x16),
          Row(
            children: [
              Expanded(
                child: SfMetric(
                  label: 'Quãng đường',
                  value: distance.toStringAsFixed(1),
                  unit: 'km',
                ),
              ),
              Expanded(
                child: SfMetric(
                  label: 'Thời gian',
                  value: '${duration.ceil()}',
                  unit: 'phút',
                ),
              ),
              Expanded(
                child: SfMetric(
                  label: 'Điểm ngập',
                  value: '${_floodPoints.length}',
                  valueColor: _floodPoints.isEmpty ? null : SfColors.amber,
                ),
              ),
            ],
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: SfSpace.x12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.water_drop_outlined,
                  size: 16,
                  color: SfColors.amber,
                ),
                const SizedBox(width: SfSpace.x8),
                Expanded(
                  child: Text(
                    warnings.take(2).join(' · '),
                    style: SfType.meta.copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
