class DriverBootstrap {
  const DriverBootstrap({
    required this.profile,
    required this.safety,
    required this.config,
    required this.currentAssignment,
    required this.todayTrips,
    required this.floodPoints,
    required this.notifications,
    required this.serverTime,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic> safety;
  final Map<String, dynamic> config;
  final Map<String, dynamic>? currentAssignment;
  final List<Map<String, dynamic>> todayTrips;
  final List<Map<String, dynamic>> floodPoints;
  final List<Map<String, dynamic>> notifications;
  final DateTime? serverTime;

  factory DriverBootstrap.fromJson(Map<String, dynamic> json) =>
      DriverBootstrap(
        profile: Map<String, dynamic>.from(json['profile'] as Map? ?? const {}),
        safety: Map<String, dynamic>.from(json['safety'] as Map? ?? const {}),
        config: Map<String, dynamic>.from(json['config'] as Map? ?? const {}),
        currentAssignment: json['currentAssignment'] == null
            ? null
            : Map<String, dynamic>.from(json['currentAssignment'] as Map),
        todayTrips: maps(json['todayTrips']),
        floodPoints: maps(json['activeFloodPoints']),
        notifications: maps(json['notifications']),
        serverTime: DateTime.tryParse(json['serverTime']?.toString() ?? ''),
      );

  Map<String, dynamic>? get driver => profile['driver'] is Map
      ? Map<String, dynamic>.from(profile['driver'] as Map)
      : null;
  Map<String, dynamic>? get currentTrip {
    final trip = currentAssignment?['trip'];
    return trip is Map ? Map<String, dynamic>.from(trip) : null;
  }

  static List<Map<String, dynamic>> maps(Object? source) => source is List
      ? source.map((item) => Map<String, dynamic>.from(item as Map)).toList()
      : const [];
}

class NavigationRoute {
  const NavigationRoute({
    required this.sessionId,
    required this.safe,
    required this.selectedRouteIndex,
    required this.routes,
  });

  final String sessionId;
  final bool safe;
  final int selectedRouteIndex;
  final List<Map<String, dynamic>> routes;

  factory NavigationRoute.fromJson(Map<String, dynamic> json) =>
      NavigationRoute(
        sessionId: json['sessionId']?.toString() ?? '',
        safe: json['safe'] == true,
        selectedRouteIndex: (json['selectedRouteIndex'] as num?)?.toInt() ?? 0,
        routes: DriverBootstrap.maps(json['routes']),
      );

  Map<String, dynamic> get selected =>
      routes[selectedRouteIndex.clamp(0, routes.length - 1)];
}

class LocationPoint {
  const LocationPoint({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.id,
    this.source,
  });

  final String? id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? source;

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
    id: json['id']?.toString(),
    name: json['name']?.toString() ?? 'Địa điểm',
    address: json['address']?.toString() ?? '',
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    source: json['source']?.toString(),
  );
}
