import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';
import 'trip_detail_screen.dart';

enum TripDayBucket { upcoming, active, completed, cancelled }

enum _TripFilter { all, upcoming, active, completed }

TripDayBucket tripDayBucket(Object? rawStatus) {
  return switch (rawStatus?.toString().toUpperCase()) {
    'IN_PROGRESS' || 'RESTING' => TripDayBucket.active,
    'COMPLETED' => TripDayBucket.completed,
    'CANCELLED' || 'REJECTED' => TripDayBucket.cancelled,
    _ => TripDayBucket.upcoming,
  };
}

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
  Widget build(BuildContext context) {
    final p = context.sf;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Lịch trình hôm nay'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Tải lại lịch trình',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: SfSpace.x4),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              padding: const EdgeInsets.all(SfSpace.x16),
              children: [
                const SfSkeleton(height: 148, radius: SfRadius.card),
                const SizedBox(height: SfSpace.x20),
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
                  SizedBox(height: MediaQuery.sizeOf(context).height * .2),
                  SfEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Không tải được lịch trình',
                    message:
                        '${snapshot.error}\nKéo xuống để thử lại. Chuyến đã tải trước đó vẫn xem được.',
                  ),
                ],
              ),
            );
          }
          return _content(snapshot.data ?? const []);
        },
      ),
    );
  }

  Widget _content(List<Map<String, dynamic>> trips) {
    final upcoming = _withBucket(trips, TripDayBucket.upcoming);
    final active = _withBucket(trips, TripDayBucket.active);
    final completed = _withBucket(trips, TripDayBucket.completed);
    final visible = switch (_filter) {
      _TripFilter.all => trips,
      _TripFilter.upcoming => upcoming,
      _TripFilter.active => active,
      _TripFilter.completed => completed,
    };
    final sorted = [...visible]
      ..sort((a, b) {
        final left = DateTime.tryParse(a['plannedStartTime']?.toString() ?? '');
        final right = DateTime.tryParse(b['plannedStartTime']?.toString() ?? '');
        if (left == null || right == null) return 0;
        return left.compareTo(right);
      });

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          SfSpace.x16,
          SfSpace.x8,
          SfSpace.x16,
          SfSpace.x40 + SfSpace.x40,
        ),
        children: [
          _DayOverview(
            total: trips.length,
            upcoming: upcoming.length,
            active: active.length,
            completed: completed.length,
          ),
          const SizedBox(height: SfSpace.x20),
          _FilterBar(
            value: _filter,
            counts: {
              _TripFilter.all: trips.length,
              _TripFilter.upcoming: upcoming.length,
              _TripFilter.active: active.length,
              _TripFilter.completed: completed.length,
            },
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: SfSpace.x20),
          if (sorted.isEmpty)
            SfEmptyState(
              icon: _filterIcon(_filter),
              title: _filter == _TripFilter.all
                  ? 'Hôm nay chưa có chuyến'
                  : 'Không có chuyến ở bộ lọc này',
              message: _filter == _TripFilter.all
                  ? 'Chuyến do điều phối giao sẽ tự hiện ở đây.'
                  : 'Chọn bộ lọc khác hoặc kéo xuống để cập nhật.',
            )
          else
            // Trục thời gian dọc: tài xế đọc cả ngày theo thứ tự giờ chạy,
            // không phải theo nhóm trạng thái.
            for (var i = 0; i < sorted.length; i++)
              _ScheduleRow(
                trip: sorted[i],
                isLast: i == sorted.length - 1,
                onTap: () => _openTrip(sorted[i]),
              ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _withBucket(
    List<Map<String, dynamic>> trips,
    TripDayBucket bucket,
  ) => trips.where((trip) => tripDayBucket(trip['status']) == bucket).toList();
}

/// Một dòng lịch trình: cột giờ bên trái + thẻ chuyến bên phải.
class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.trip,
    required this.isLast,
    required this.onTap,
  });

  final Map<String, dynamic> trip;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final status = trip['status']?.toString().toUpperCase() ?? 'ASSIGNED';
    final bucket = tripDayBucket(status);
    final tone = _statusOf(status);
    final active = bucket == TripDayBucket.active;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(
                  _time(trip['plannedStartTime']),
                  style: SfType.mono.copyWith(
                    color: active ? p.accent : p.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SfSpace.x8),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: active ? tone.inkOf(p) : p.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: tone.inkOf(p), width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(
                        vertical: SfSpace.x4,
                      ),
                      color: p.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : SfSpace.x16),
              child: SfTripCard(
                code: trip['tripCode']?.toString() ?? 'Chuyến #${trip['id']}',
                origin: trip['startLocation']?.toString() ?? '--',
                destination: trip['endLocation']?.toString() ?? '--',
                status: tone,
                statusLabel: _statusLabel(status),
                heroTag: 'trip-${trip['id']}',
                emphasized: active,
                plate: trip['vehiclePlateNumber']?.toString(),
                metrics: [
                  SfTripMetric(
                    'Dự kiến',
                    _duration(trip),
                    icon: Icons.timelapse_rounded,
                  ),
                  SfTripMetric(
                    'Rủi ro',
                    _riskLabel(trip['riskLevel']?.toString() ?? 'LOW'),
                    icon: Icons.shield_outlined,
                  ),
                  if (active)
                    SfTripMetric(
                      'Tiến độ',
                      '${_progress(trip).round()}%',
                      icon: Icons.trending_up_rounded,
                    ),
                ],
                onTap: onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dải tổng quan ngày — nền tối để tách khỏi danh sách phía dưới.
class _DayOverview extends StatelessWidget {
  const _DayOverview({
    required this.total,
    required this.upcoming,
    required this.active,
    required this.completed,
  });

  final int total;
  final int upcoming;
  final int active;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(SfSpace.x20),
      decoration: const BoxDecoration(
        color: SfColors.navy,
        borderRadius: SfRadius.cardR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: SfTouch.min,
                height: SfTouch.min,
                decoration: const BoxDecoration(
                  color: SfColors.navy700,
                  borderRadius: SfRadius.controlR,
                ),
                child: Center(
                  child: Text(
                    now.day.toString().padLeft(2, '0'),
                    style: SfType.titleCard.copyWith(
                      color: SfColors.darkTextPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SfSpace.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _weekday(now.weekday),
                      style: SfType.titleCard.copyWith(
                        color: SfColors.darkTextPrimary,
                      ),
                    ),
                    Text(
                      'Tháng ${now.month}, ${now.year}',
                      style: SfType.meta.copyWith(
                        color: SfColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SfSpace.x12,
                  vertical: SfSpace.x4 + 2,
                ),
                decoration: const BoxDecoration(
                  color: SfColors.navy700,
                  borderRadius: SfRadius.pillR,
                ),
                child: Text(
                  '$total chuyến',
                  style: SfType.mono.copyWith(color: SfColors.mint),
                ),
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x20),
          Row(
            children: [
              _metric('Chưa đi', upcoming),
              _divider(),
              _metric('Đang chạy', active, accent: SfColors.mint),
              _divider(),
              _metric('Đã đi', completed),
            ],
          ),
          const SizedBox(height: SfSpace.x16),
          Row(
            children: [
              Text(
                'Tiến độ ngày',
                style: SfType.meta.copyWith(color: SfColors.darkTextSecondary),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: SfType.mono.copyWith(color: SfColors.darkTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x8),
          ClipRRect(
            borderRadius: SfRadius.pillR,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: SfColors.navy700,
              valueColor: const AlwaysStoppedAnimation<Color>(SfColors.mint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, int value, {Color? accent}) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: SfType.titleScreen.copyWith(
            color: accent ?? SfColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: SfSpace.x4),
        Text(
          label.toUpperCase(),
          style: SfType.label.copyWith(color: SfColors.darkTextSecondary),
        ),
      ],
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: SfSpace.x32, color: SfColors.navy700);
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.value,
    required this.counts,
    required this.onChanged,
  });

  final _TripFilter value;
  final Map<_TripFilter, int> counts;
  final ValueChanged<_TripFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _TripFilter.values.map((filter) {
          final selected = filter == value;
          return Padding(
            padding: const EdgeInsets.only(right: SfSpace.x8),
            child: Material(
              color: selected ? p.accent : p.surface,
              borderRadius: SfRadius.pillR,
              child: InkWell(
                borderRadius: SfRadius.pillR,
                onTap: () => onChanged(filter),
                child: Container(
                  height: SfTouch.min,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SfSpace.x16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: SfRadius.pillR,
                    border: Border.all(
                      color: selected ? p.accent : p.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _filterIcon(filter),
                        size: 17,
                        color: selected ? p.onAccent : p.textSecondary,
                      ),
                      const SizedBox(width: SfSpace.x8),
                      Text(
                        '${_filterTitle(filter)} ${counts[filter] ?? 0}',
                        style: SfType.meta.copyWith(
                          color: selected ? p.onAccent : p.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
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

String _riskLabel(String value) => switch (value.toUpperCase()) {
  'CRITICAL' => 'Rất cao',
  'HIGH' => 'Cao',
  'MEDIUM' => 'Vừa',
  _ => 'Thấp',
};

String _filterTitle(_TripFilter filter) => switch (filter) {
  _TripFilter.all => 'Tất cả',
  _TripFilter.upcoming => 'Chưa đi',
  _TripFilter.active => 'Đang chạy',
  _TripFilter.completed => 'Đã đi',
};

IconData _filterIcon(_TripFilter filter) => switch (filter) {
  _TripFilter.all => Icons.view_agenda_outlined,
  _TripFilter.upcoming => Icons.schedule_rounded,
  _TripFilter.active => Icons.navigation_rounded,
  _TripFilter.completed => Icons.task_alt_rounded,
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
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _duration(Map<String, dynamic> trip) {
  final start = DateTime.tryParse(trip['plannedStartTime']?.toString() ?? '');
  final end = DateTime.tryParse(trip['estimatedEndTime']?.toString() ?? '');
  if (start == null || end == null || !end.isAfter(start)) return '--';
  final minutes = end.difference(start).inMinutes;
  if (minutes < 60) return '$minutes phút';
  final hours = minutes ~/ 60;
  final remain = minutes % 60;
  return remain == 0 ? '$hours giờ' : '${hours}g $remain phút';
}

String _weekday(int weekday) => switch (weekday) {
  DateTime.monday => 'Thứ Hai',
  DateTime.tuesday => 'Thứ Ba',
  DateTime.wednesday => 'Thứ Tư',
  DateTime.thursday => 'Thứ Năm',
  DateTime.friday => 'Thứ Sáu',
  DateTime.saturday => 'Thứ Bảy',
  _ => 'Chủ Nhật',
};
