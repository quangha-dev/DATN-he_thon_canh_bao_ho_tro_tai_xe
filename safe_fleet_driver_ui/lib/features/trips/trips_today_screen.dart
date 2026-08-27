import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';
import 'trip_detail_screen.dart';

enum TripDayBucket { upcoming, active, completed, cancelled }

enum _TripFilter { all, active, upcoming, completed }

TripDayBucket tripDayBucket(Object? rawStatus) {
  return switch (rawStatus?.toString().toUpperCase()) {
    'IN_PROGRESS' || 'RESTING' => TripDayBucket.active,
    'COMPLETED' => TripDayBucket.completed,
    'CANCELLED' || 'REJECTED' => TripDayBucket.cancelled,
    _ => TripDayBucket.upcoming,
  };
}

/// Chuyến của tôi — danh sách chuyến trong ngày, nhóm theo trạng thái.
class TripsTodayScreen extends ConsumerStatefulWidget {
  const TripsTodayScreen({super.key});

  @override
  ConsumerState<TripsTodayScreen> createState() => _TripsTodayScreenState();
}

class _TripsTodayScreenState extends ConsumerState<TripsTodayScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  _TripFilter _filter = _TripFilter.all;

  @override
  void initState() {
    super.initState();
    _future = ref.read(driverRepositoryProvider).tripsToday();
  }

  Future<void> _refresh() async {
    final next = ref.read(driverRepositoryProvider).tripsToday();
    setState(() => _future = next);
    await next;
  }

  void _openTrip(Map<String, dynamic> trip) {
    Navigator.push<void>(
      context,
      SfMorphRoute<void>(
        builder: (_) => TripDetailScreen(tripId: (trip['id'] as num).toInt()),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) => SfSubScreen(
    title: 'Chuyến của tôi',
    subtitle: 'Lịch trình hôm nay',
    scrollable: false,
    padding: EdgeInsets.zero,
    trailing: SfIconButton(
      icon: Icons.filter_list_rounded,
      onHero: true,
      tooltip: 'Tải lại lịch trình',
      onTap: _refresh,
    ),
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ListView(
            padding: SfSpace.screenSub,
            children: [
              SfSkeleton.card(lines: 4),
              const SizedBox(height: SfSpace.x12),
              SfSkeleton.card(lines: 4),
            ],
          );
        }
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * .15),
                SfEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Không tải được lịch trình',
                  message:
                      '${snapshot.error}\nKéo xuống để thử lại. '
                      'Chuyến đã tải trước đó vẫn xem được.',
                ),
              ],
            ),
          );
        }
        return _content(snapshot.data ?? const []);
      },
    ),
  );

  Widget _content(List<Map<String, dynamic>> trips) {
    final upcoming = _withBucket(trips, TripDayBucket.upcoming);
    final active = _withBucket(trips, TripDayBucket.active);
    final completed = _withBucket(trips, TripDayBucket.completed);
    final counts = {
      _TripFilter.all: trips.length,
      _TripFilter.active: active.length,
      _TripFilter.upcoming: upcoming.length,
      _TripFilter.completed: completed.length,
    };

    final showActive =
        _filter == _TripFilter.all || _filter == _TripFilter.active;
    final showUpcoming =
        _filter == _TripFilter.all || _filter == _TripFilter.upcoming;
    final showCompleted =
        _filter == _TripFilter.all || _filter == _TripFilter.completed;

    final visible = [
      if (showActive) ...active,
      if (showUpcoming) ...upcoming,
      if (showCompleted) ...completed,
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: SfSpace.screenSub,
        children: [
          _filterBar(counts),
          const SizedBox(height: SfSpace.x16),
          if (visible.isEmpty)
            SfEmptyState(
              icon: Icons.event_busy_rounded,
              title: _filter == _TripFilter.all
                  ? 'Hôm nay chưa có chuyến'
                  : 'Không có chuyến ở bộ lọc này',
              message: _filter == _TripFilter.all
                  ? 'Chuyến do điều phối giao sẽ tự hiện ở đây.'
                  : 'Chọn bộ lọc khác hoặc kéo xuống để cập nhật.',
            ),
          if (showActive)
            for (final trip in _sorted(active)) ...[
              _tripCard(trip, emphasized: true),
              const SizedBox(height: SfSpace.x12),
            ],
          if (showUpcoming)
            for (final trip in _sorted(upcoming)) ...[
              _tripCard(trip),
              const SizedBox(height: SfSpace.x12),
            ],
          if (showCompleted && completed.isNotEmpty) ...[
            const SizedBox(height: SfSpace.x4),
            const SfSectionLabel('Đã hoàn thành'),
            const SizedBox(height: SfSpace.x10),
            _completedGroup(_sorted(completed)),
          ],
        ],
      ),
    );
  }

  Widget _filterBar(Map<_TripFilter, int> counts) => SizedBox(
    height: 36,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _TripFilter.values.length,
      separatorBuilder: (_, _) => const SizedBox(width: SfSpace.x8),
      itemBuilder: (_, index) {
        final filter = _TripFilter.values[index];
        return SfFilterChip(
          label: '${_filterTitle(filter)} · ${counts[filter] ?? 0}',
          selected: filter == _filter,
          onTap: () => setState(() => _filter = filter),
        );
      },
    ),
  );

  Widget _tripCard(Map<String, dynamic> trip, {bool emphasized = false}) {
    final status = trip['status']?.toString().toUpperCase() ?? 'ASSIGNED';
    final risk = trip['riskLevel']?.toString().toUpperCase() ?? 'LOW';
    final highRisk = risk == 'HIGH' || risk == 'CRITICAL';
    final needsChecklist =
        tripDayBucket(status) == TripDayBucket.upcoming &&
        trip['checklistCompleted'] != true;

    return SfTripCard(
      code: trip['tripCode']?.toString() ?? 'Chuyến #${trip['id']}',
      origin: trip['startLocation']?.toString() ?? '--',
      destination: trip['endLocation']?.toString() ?? '--',
      status: _statusOf(status),
      statusLabel: _statusLabel(status),
      riskLabel: highRisk ? 'Rủi ro cao' : null,
      summary: _summary(trip, needsChecklist: needsChecklist),
      departAt: _time(trip['plannedStartTime']),
      arriveAt: _time(trip['estimatedEndTime']),
      progress: emphasized ? _progress(trip) / 100 : null,
      heroTag: 'trip-${trip['id']}',
      emphasized: emphasized,
      onTap: () => _openTrip(trip),
    );
  }

  /// "32,5 km · hàng lạnh · 2 điểm ngập trên tuyến"
  String _summary(Map<String, dynamic> trip, {required bool needsChecklist}) {
    final distance = (trip['distanceKm'] as num?)?.toDouble();
    final cargo = trip['cargoType']?.toString();
    final floods = (trip['floodPointCount'] as num?)?.toInt() ?? 0;
    return [
      if (distance != null) '${distance.toStringAsFixed(1)} km',
      if (cargo != null && cargo.isNotEmpty) cargo,
      if (floods > 0) '$floods điểm ngập trên tuyến',
      if (needsChecklist) 'cần checklist trước khi đi',
    ].join(' · ');
  }

  /// Chuyến đã xong gộp trong một thẻ, mỗi dòng có icon check và điểm an toàn.
  Widget _completedGroup(List<Map<String, dynamic>> trips) {
    final p = context.sf;
    return SfCard(
      padding: const EdgeInsets.symmetric(vertical: SfSpace.x4),
      child: Column(
        children: [
          for (var i = 0; i < trips.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.border),
            _completedRow(trips[i]),
          ],
        ],
      ),
    );
  }

  Widget _completedRow(Map<String, dynamic> trip) {
    final p = context.sf;
    final score = (trip['safetyScore'] as num?)?.round();
    final status = score == null ? SfStatus.good : SfScoreRing.statusOf(score);
    return SfListRow(
      leading: const SfIconTile(icon: Icons.check_rounded, size: 34),
      title:
          '${trip['startLocation'] ?? '--'} → ${trip['endLocation'] ?? '--'}',
      subtitle:
          '${_time(trip['plannedStartTime'])} · '
          '${trip['tripCode'] ?? 'Chuyến #${trip['id']}'}',
      trailing: score == null
          ? null
          : Text(
              '$scoređ',
              style: SfType.mono.copyWith(
                color: status.inkOf(p),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
      onTap: () => _openTrip(trip),
    );
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> trips) =>
      [...trips]..sort((a, b) {
        final left = DateTime.tryParse(a['plannedStartTime']?.toString() ?? '');
        final right = DateTime.tryParse(
          b['plannedStartTime']?.toString() ?? '',
        );
        if (left == null || right == null) return 0;
        return left.compareTo(right);
      });

  List<Map<String, dynamic>> _withBucket(
    List<Map<String, dynamic>> trips,
    TripDayBucket bucket,
  ) => trips.where((trip) => tripDayBucket(trip['status']) == bucket).toList();
}

double _progress(Map<String, dynamic> trip) =>
    ((trip['progress'] as num?)?.toDouble() ?? 0).clamp(0, 100);

SfStatus _statusOf(String status) => switch (status) {
  'IN_PROGRESS' => SfStatus.good,
  'COMPLETED' => SfStatus.good,
  'RESTING' => SfStatus.pending,
  'DELAYED' => SfStatus.warning,
  'CANCELLED' => SfStatus.warning,
  'INCIDENT' => SfStatus.danger,
  _ => SfStatus.pending,
};

String _filterTitle(_TripFilter filter) => switch (filter) {
  _TripFilter.all => 'Tất cả',
  _TripFilter.active => 'Đang chạy',
  _TripFilter.upcoming => 'Chờ đi',
  _TripFilter.completed => 'Đã xong',
};

String _statusLabel(String status) => switch (status) {
  'DRAFT' => 'Chờ giao',
  'ASSIGNED' => 'Đã giao',
  'ACCEPTED' => 'Đã nhận',
  'IN_PROGRESS' => 'Đang chạy',
  'RESTING' => 'Đang nghỉ',
  'COMPLETED' => 'Hoàn thành',
  'DELAYED' => 'Trễ giờ',
  'INCIDENT' => 'Có sự cố',
  'REJECTED' => 'Đã từ chối',
  'CANCELLED' => 'Đã hủy',
  _ => status,
};

String _time(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return '--:--';
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
