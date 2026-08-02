import 'package:flutter_test/flutter_test.dart';
import 'package:safe_fleet_driver_ui/features/trips/trip_detail_screen.dart';
import 'package:safe_fleet_driver_ui/features/trips/trips_today_screen.dart';

void main() {
  test('today trip statuses are grouped for driver schedule', () {
    expect(tripDayBucket('ASSIGNED'), TripDayBucket.upcoming);
    expect(tripDayBucket('ACCEPTED'), TripDayBucket.upcoming);
    expect(tripDayBucket('IN_PROGRESS'), TripDayBucket.active);
    expect(tripDayBucket('RESTING'), TripDayBucket.active);
    expect(tripDayBucket('COMPLETED'), TripDayBucket.completed);
    expect(tripDayBucket('CANCELLED'), TripDayBucket.cancelled);
  });

  test('dispatch metadata from web is decoded for mobile trip detail', () {
    final info = tripDispatchInfo('''
      {"cargoInfo":"Thiết bị điện tử · 120 kg","notes":"Giao nguyên kiện","dispatchedBy":{"id":1,"fullName":"Quan tri he thong"}}
    ''');

    expect(info['cargoInfo'], 'Thiết bị điện tử · 120 kg');
    expect(info['dispatchedBy'], 'Quan tri he thong');
    expect(info['notes'], 'Giao nguyên kiện');
  });

  test('warehouse issue document keeps recipient and multiple cargo rows', () {
    final info = tripDispatchInfo('''
      {"warehouseDocument":{"issueNumber":"PXK-001","warehouseName":"Kho A","projectName":"Công trình Bắc Hưng Yên","recipient":{"name":"Nguyễn Văn B","phone":"0912345678"},"items":[{"itemCode":"PHC-300","description":"Ống PHC D300","unit":"mét","quantityIssued":280,"quantityReturned":0},{"itemCode":"MD-D300","description":"Mũi dẫn cọc D300","unit":"cái","quantityIssued":14,"quantityReturned":0}]}}
    ''');

    expect(info['issueNumber'], 'PXK-001');
    expect(info['recipientName'], 'Nguyễn Văn B');
    expect(info['items'], hasLength(2));
    expect((info['items'] as List).first['quantityIssued'], 280);
  });
}
