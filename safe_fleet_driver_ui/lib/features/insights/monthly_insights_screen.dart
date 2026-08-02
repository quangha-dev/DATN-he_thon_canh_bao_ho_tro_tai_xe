import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';

class MonthlyInsightsScreen extends ConsumerStatefulWidget {
  const MonthlyInsightsScreen({super.key});

  @override
  ConsumerState<MonthlyInsightsScreen> createState() =>
      _MonthlyInsightsScreenState();
}

class _MonthlyInsightsScreenState extends ConsumerState<MonthlyInsightsScreen> {
  late DateTime _month;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  void _load() {
    _future = ref.read(driverRepositoryProvider).monthlyActivity(month: _month);
  }

  void _changeMonth(int offset) {
    final next = DateTime(_month.year, _month.month + offset);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _month = next;
      _load();
    });
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: const Text('Báo cáo tháng')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(SfSpace.x16),
              children: [
                const SfSkeleton(height: 168, radius: SfRadius.card),
                const SizedBox(height: SfSpace.x16),
                SfSkeleton.card(lines: 3),
              ],
            );
          }
          if (snapshot.hasError) {
            return SfEmptyState(
              icon: Icons.insights_outlined,
              title: 'Chưa tải được báo cáo',
              message:
                  '${snapshot.error}\nBáo cáo lấy từ máy chủ nên cần kết nối mạng.',
              action: TextButton(
                onPressed: () => setState(_load),
                child: const Text('Tải lại'),
              ),
            );
          }

          final data = snapshot.requireData;
          final days = (data['days'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          final achievements = (data['achievements'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SfSpace.x16,
                SfSpace.x8,
                SfSpace.x16,
                SfSpace.x40 + SfSpace.x40,
              ),
              children: [
                _MonthSelector(month: _month, onChange: _changeMonth),
                const SizedBox(height: SfSpace.x16),
                _AchievementHero(data: data),
                const SizedBox(height: SfSpace.x24),
                const SfSectionLabel('Kết quả vận hành'),
                const SizedBox(height: SfSpace.x8),
                _OperationsGrid(data: data),
                const SizedBox(height: SfSpace.x24),
                const SfSectionLabel('An toàn và sức khoẻ'),
                const SizedBox(height: SfSpace.x8),
                _SafetyCard(data: data),
                const SizedBox(height: SfSpace.x24),
                const SfSectionLabel('Nhịp độ 4 tuần'),
                const SizedBox(height: SfSpace.x8),
                SfCard(child: _WeekBars(days: days)),
                const SizedBox(height: SfSpace.x24),
                const SfSectionLabel('Huy hiệu tháng'),
                const SizedBox(height: SfSpace.x8),
                if (achievements.isEmpty)
                  SfCard(
                    child: Text(
                      'Tháng này chưa có dữ liệu huy hiệu.',
                      style: SfType.body.copyWith(color: p.textSecondary),
                    ),
                  )
                else
                  for (final item in achievements) _AchievementTile(item),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month, required this.onChange});

  final DateTime month;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final now = DateTime.now();
    final current = month.year == now.year && month.month == now.month;
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => onChange(-1),
          tooltip: 'Tháng trước',
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'Tháng ${month.month} · ${month.year}',
                style: SfType.titleCard.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: SfSpace.x4),
              Text(
                current ? 'Đang diễn ra' : 'Đã chốt theo dữ liệu hệ thống',
                style: SfType.meta.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: current ? null : () => onChange(1),
          tooltip: 'Tháng sau',
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// Thẻ thành tích — chỗ duy nhất trong app được phép "đẹp", vì nó nói về kết
/// quả cả tháng chứ không phải một quyết định đang cần xử lý.
class _AchievementHero extends StatelessWidget {
  const _AchievementHero({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final level = data['achievementLevel']?.toString() ?? 'BRONZE';
    final (accent, levelLabel) = switch (level) {
      'GOLD' => (SfColors.amber, 'Hạng vàng'),
      'SILVER' => (SfColors.darkTextSecondary, 'Hạng bạc'),
      _ => (SfColors.mint, 'Hạng đồng'),
    };
    final score = (data['safetyScore'] as num?)?.round() ?? 0;

    return Container(
      padding: const EdgeInsets.all(SfSpace.x20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SfColors.navy, SfColors.navy700],
        ),
        borderRadius: SfRadius.cardR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: SfColors.navy,
                  size: 32,
                ),
              ),
              const SizedBox(width: SfSpace.x16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      levelLabel.toUpperCase(),
                      style: SfType.label.copyWith(color: accent),
                    ),
                    const SizedBox(height: SfSpace.x4),
                    Text(
                      data['achievementTitle']?.toString() ??
                          'Đang xây dựng thành tích',
                      style: SfType.titleCard.copyWith(
                        color: SfColors.darkTextPrimary,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score',
                    style: SfType.displayDrive.copyWith(
                      color: accent,
                      fontSize: 32,
                    ),
                  ),
                  Text(
                    'ĐIỂM',
                    style: SfType.label.copyWith(
                      color: SfColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x20),
          Row(
            children: [
              _fact(
                '${data['completedTrips'] ?? 0}/${data['totalTrips'] ?? 0}',
                'chuyến hoàn thành',
              ),
              _fact('${data['onTimeRate'] ?? 0}%', 'đúng hẹn'),
              _fact('${_decimal(data['distanceKm'])} km', 'quãng đường'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fact(String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: SfType.mono.copyWith(
            color: SfColors.darkTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: SfSpace.x4),
        Text(
          label,
          style: SfType.meta.copyWith(color: SfColors.darkTextSecondary),
        ),
      ],
    ),
  );
}

class _OperationsGrid extends StatelessWidget {
  const _OperationsGrid({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final items = <(IconData, String, String)>[
      (
        Icons.task_alt_rounded,
        '${data['completionRate'] ?? 0}%',
        'Tỷ lệ hoàn thành',
      ),
      (Icons.timer_outlined, '${data['onTimeTrips'] ?? 0}', 'Chuyến đúng giờ'),
      (
        Icons.route_rounded,
        '${_decimal(data['distanceKm'])} km',
        'Tổng quãng đường',
      ),
      (
        Icons.calendar_month_outlined,
        '${data['activeDays'] ?? 0} ngày',
        'Ngày hoạt động',
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: SfSpace.x12,
      crossAxisSpacing: SfSpace.x12,
      childAspectRatio: 1.65,
      children: [
        for (final item in items)
          SfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.$1, color: p.accent, size: 22),
                const SizedBox(height: SfSpace.x12),
                Text(
                  item.$2,
                  style: SfType.mono.copyWith(
                    color: p.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  item.$3.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.label.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final driving = (data['drivingMinutes'] as num?)?.toInt() ?? 0;
    final resting = (data['restMinutes'] as num?)?.toInt() ?? 0;
    final critical = (data['criticalAlertCount'] as num?)?.toInt() ?? 0;
    return SfCard(
      child: Column(
        children: [
          _row(
            context,
            Icons.shield_outlined,
            'Ngày không cảnh báo',
            '${data['alertFreeDays'] ?? 0}/${data['activeDays'] ?? 0} ngày',
            SfStatus.good,
          ),
          const Divider(height: SfSpace.x24),
          _row(
            context,
            Icons.warning_amber_rounded,
            'Cảnh báo an toàn',
            '${data['alertCount'] ?? 0} tổng · $critical nghiêm trọng',
            critical > 0 ? SfStatus.danger : SfStatus.warning,
          ),
          const Divider(height: SfSpace.x24),
          _row(
            context,
            Icons.schedule_rounded,
            'Thời gian lái / nghỉ',
            '${_duration(driving)} / ${_duration(resting)}',
            SfStatus.pending,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    SfStatus status,
  ) {
    final p = context.sf;
    final ink = status.inkOf(p);
    return Row(
      children: [
        Container(
          width: SfTouch.min - 8,
          height: SfTouch.min - 8,
          decoration: BoxDecoration(
            color: status.tint(p),
            borderRadius: SfRadius.controlR,
          ),
          child: Icon(icon, color: ink, size: 20),
        ),
        const SizedBox(width: SfSpace.x12),
        Expanded(
          child: Text(
            label,
            style: SfType.body.copyWith(color: p.textSecondary),
          ),
        ),
        Text(
          value,
          style: SfType.mono.copyWith(
            color: p.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile(this.data);

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final unlocked = data['unlocked'] == true;
    final progress = ((data['progress'] as num?)?.toDouble() ?? 0).clamp(
      0,
      100,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: SfSpace.x8),
      child: SfCard(
        emphasis: unlocked ? SfStatus.good : null,
        child: Row(
          children: [
            Container(
              width: SfTouch.min,
              height: SfTouch.min,
              decoration: BoxDecoration(
                color: unlocked ? SfColors.amberTint : p.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                unlocked
                    ? Icons.emoji_events_rounded
                    : Icons.lock_outline_rounded,
                color: unlocked ? SfColors.amber : p.textMuted,
              ),
            ),
            const SizedBox(width: SfSpace.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['title']?.toString() ?? '--',
                          style: SfType.titleCard.copyWith(
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        unlocked ? 'Đã đạt' : '${progress.round()}%',
                        style: SfType.mono.copyWith(
                          color: unlocked ? SfColors.success : p.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SfSpace.x4),
                  Text(
                    data['description']?.toString() ?? '',
                    style: SfType.meta.copyWith(color: p.textSecondary),
                  ),
                  if (!unlocked) ...[
                    const SizedBox(height: SfSpace.x8),
                    ClipRRect(
                      borderRadius: SfRadius.pillR,
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 6,
                        backgroundColor: p.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(p.accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});

  final List<Map<String, dynamic>> days;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final weekly = List.generate(4, (weekIndex) {
      final start = weekIndex * 7;
      if (start >= days.length) return 0;
      final end = (start + 7).clamp(0, days.length);
      return days
          .sublist(start, end)
          .fold<int>(
            0,
            (sum, day) => sum + ((day['drivingMinutes'] as num?)?.toInt() ?? 0),
          );
    });
    final maximum = weekly.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    return SizedBox(
      height: 148,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          final height = 16 + weekly[index] / maximum * 72;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SfSpace.x8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _duration(weekly[index]),
                    style: SfType.mono.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: SfSpace.x8),
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: SfRadius.controlR,
                    ),
                  ),
                  const SizedBox(height: SfSpace.x8),
                  Text(
                    'TUẦN ${index + 1}',
                    style: SfType.label.copyWith(color: p.textMuted),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

String _decimal(Object? value) {
  final number = (value as num?)?.toDouble() ?? 0;
  return number == number.roundToDouble()
      ? number.toInt().toString()
      : number.toStringAsFixed(1);
}

String _duration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest phút';
  return rest == 0 ? '$hours giờ' : '${hours}g $rest';
}
