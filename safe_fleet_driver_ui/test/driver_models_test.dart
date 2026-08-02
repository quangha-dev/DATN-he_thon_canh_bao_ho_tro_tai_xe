import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/models/driver_models.dart';

void main() {
  test('bootstrap parses driver, assignment and cacheable lists', () {
    final bootstrap = DriverBootstrap.fromJson({
      'profile': {
        'driver': {'id': 8, 'fullName': 'Bui Hai Dang'},
      },
      'safety': {'safetyScore': 92},
      'config': {'maxContinuousDrivingMinutes': 240},
      'currentAssignment': {
        'trip': {'id': 18, 'status': 'ASSIGNED'},
      },
      'todayTrips': [
        {'id': 18},
      ],
      'activeFloodPoints': [
        {'id': 3},
      ],
      'notifications': [
        {'id': 9},
      ],
      'serverTime': '2026-07-27T00:00:00',
    });

    expect(bootstrap.driver?['id'], 8);
    expect(bootstrap.currentTrip?['status'], 'ASSIGNED');
    expect(bootstrap.todayTrips, hasLength(1));
    expect(bootstrap.floodPoints, hasLength(1));
    expect(bootstrap.notifications, hasLength(1));
  });

  test('navigation selects backend recommended alternative', () {
    final navigation = NavigationRoute.fromJson({
      'sessionId': 'session-1',
      'safe': true,
      'selectedRouteIndex': 1,
      'routes': [
        {'routeIndex': 0, 'provider': 'OSRM'},
        {'routeIndex': 1, 'provider': 'LOCAL_DETERMINISTIC'},
      ],
    });

    expect(navigation.safe, isTrue);
    expect(navigation.selected['routeIndex'], 1);
  });
}
