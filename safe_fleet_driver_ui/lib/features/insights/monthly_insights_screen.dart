import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';
import '../documents/driving_log_list_screen.dart';

/// Báo cáo tháng — tab thứ tư.
///
/// Đây là chỗ duy nhất trong app nói về kết quả cả tháng chứ không phải một
/// quyết định đang cần xử lý, nên nó được phép trình bày thoáng và "đẹp" hơn.
class MonthlyInsightsScreen extends ConsumerStatefulWidget {
  const MonthlyInsightsScreen({super.key});

  @override
  ConsumerState<MonthlyInsightsScreen> createState() =>
      _MonthlyInsightsScreenState();
}

class _MonthlyInsightsScreenState extends ConsumerState<MonthlyInsightsScreen> {
  /// Giới hạn giờ lái mỗi tuần theo quy định — cột vượt ngưỡng đổi màu.
  static const _weeklyLimitMinutes = 48 * 60;

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

  void _openLogs() => Navigator.push<void>(
    context,
    SfSlideRoute<void>(builder: (_) => const DrivingLogListScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            final List<Widget> body;
            if (snapshot.hasError) {
              body = [
                SfEmptyState(
                  icon: Icons.insights_rounded,
                  title: 'Chưa tải được báo cáo',
                  message:
                      '${snapshot.error}\n'
                      'Báo cáo lấy từ máy chủ nên cần kết nối mạng.',
                  action: Column(
                    children: [
                      FilledButton.icon(
                        onPressed: _openLogs,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('Mở nhật trình offline'),
                      ),
                      TextButton(
                        onPressed: () => setState(_load),
                        child: const Text('Tải lại báo cáo máy chủ'),
                      ),
                    ],
                  ),
                ),
              ];
            } else if (!snapshot.hasData) {
              body = [
                const SfSkeleton(height: 168, radius: SfRadius.hero),
                const SizedBox(height: SfSpace.x16),
                SfSkeleton.card(lines: 3),
              ];
            } else {
              body = _content(snapshot.requireData);
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: SfSpace.screen,
                children: [_header(), const SizedBox(height: SfSpace.x18), ...body],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---- Header ----

  Widget _header() {
    final p = context.sf;
    final now = DateTime.now();
    final current = _month.year == now.year && _month.month == now.month;
    return Row(
      children: [
        // Màn này vừa là tab vừa được push từ Trợ lý — chỉ hiện nút back khi
        // thực sự có màn để quay lại.
        if (Navigator.canPop(context)) ...[
          SfIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Quay lại',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: SfSpace.x12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Báo cáo tháng',
                style: SfType.titleScreen.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                'Tháng ${_month.month}/${_month.year} · '
                '${current ? 'cập nhật ${now.day}/${now.month}' : 'đã chốt'}',
                style: SfType.caption.copyWith(color: p.textMuted),
              ),
            ],
          ),
        ),
        SfIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Tháng trước',
          onTap: () => _changeMonth(-1),
        ),
        const SizedBox(width: SfSpace.x8),
        SfIconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Tháng sau',
          onTap: current ? null : () => _changeMonth(1),
        ),
        const SizedBox(width: SfSpace.x8),
        SfIconButton(
          icon: Icons.download_rounded,
          tooltip: 'Xuất Excel',
          onTap: _openLogs,
        ),
      ],
    );
  }

  // ---- Thân màn ----

  List<Widget> _content(Map<String, dynamic> data) {
    final days = (data['days'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final achievements = (data['achievements'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return [
      _ScoreHero(data: data),
      const SizedBox(height: SfSpace.x18),
      const SfSectionLabel('Kết quả vận hành'),
      const SizedBox(height: SfSpace.x10),
      _KpiGrid(data: data),
      const SizedBox(height: SfSpace.x18),
      const SfSectionLabel('Giờ lái theo tuần'),
      const SizedBox(height: SfSpace.x10),
      _WeekBars(days: days, limitMinutes: _weeklyLimitMinutes),
      const SizedBox(height: SfSpace.x18),
      const SfSectionLabel('Vi phạm và an toàn'),
      const SizedBox(height: SfSpace.x10),
      _ViolationCard(data: data),
      if (achievements.isNotEmpty) ...[
        const SizedBox(height: SfSpace.x18),
        const SfSectionLabel('Huy hiệu tháng'),
        const SizedBox(height: SfSpace.x10),
        for (final item in achievements) _AchievementTile(item),
      ],
      const SizedBox(height: SfSpace.x14),
      SfCard(
        onTap: _openLogs,
        padding: const EdgeInsets.all(SfSpace.x14),
        child: SfListRow(
          padding: EdgeInsets.zero,
          icon: Icons.receipt_long_rounded,
          title: 'Nhật trình từ phiếu',
          subtitle: 'Xem phiếu đã lưu và xuất Excel offline',
          showChevron: true,
        ),
      ),
    ];
  }
}

/// Thẻ hero: vòng điểm 88px, xếp hạng, so sánh với tháng trước.
class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final score = (data['safetyScore'] as num?)?.round() ?? 0;
    final rank = (data['rank'] as num?)?.toInt();
    final total = (data['totalDrivers'] as num?)?.toInt();
    final delta = (data['scoreDelta'] as num?)?.toInt();

    return SfHeroCard(
      padding: const EdgeInsets.all(SfSpace.x20),
      child: Row(
        children: [
          SfScoreRing(
            score: score,
            size: 88,
            caption: 'AN TOÀN',
            onDark: true,
            color: SfColors.green300,
          ),
          const SizedBox(width: SfSpace.x18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rank == null || total == null
                      ? data['achievementTitle']?.toString() ??
                            'Đang xây dựng thành tích'
                      : 'Xếp hạng $rank/$total tài xế',
                  style: SfType.titleCard.copyWith(color: SfColors.onAccent),
                ),
                const SizedBox(height: SfSpace.x8),
                Text(
                  _deltaText(delta),
                  style: SfType.caption.copyWith(color: SfColors.green300),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _deltaText(int? delta) {
    if (delta == null || delta == 0) {
      return 'Giữ nguyên điểm so với tháng trước.';
    }
    return delta > 0
        ? 'Tăng $delta điểm so với tháng trước — giữ nhịp này.'
        : 'Giảm ${-delta} điểm so với tháng trước.';
  }
}

/// Grid 2×2 chỉ số vận hành.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final alerts = (data['alertCount'] as num?)?.toInt() ?? 0;
    final alertDelta = (data['alertCountDelta'] as num?)?.toInt();

    final cells = <Widget>[
      _cell(
        context,
        value: '${data['completedTrips'] ?? 0}',
        label: 'Chuyến hoàn tất',
        delta: _delta((data['completedTripsDelta'] as num?)?.toInt()),
      ),
      _cell(
        context,
        value: '${_decimal(data['distanceKm'])} km',
        label: 'Quãng đường',
        delta: _delta((data['distanceDeltaPercent'] as num?)?.toInt(), '%'),
      ),
      _cell(
        context,
        value: '$alerts',
        label: 'Cảnh báo buồn ngủ',
        valueColor: alerts > 0 ? SfColors.warning : null,
        delta: _delta(alertDelta, '', true),
      ),
      _cell(
        context,
        value: '${data['onTimeRate'] ?? 0}%',
        label: 'Đúng giờ',
        delta: _delta((data['onTimeRateDelta'] as num?)?.toInt(), '%'),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: SfSpace.x12,
      crossAxisSpacing: SfSpace.x12,
      childAspectRatio: 1.75,
      children: cells,
    );
  }

  Widget _cell(
    BuildContext context, {
    required String value,
    required String label,
    Color? valueColor,
    (String, Color)? delta,
  }) => SfCard(
    padding: const EdgeInsets.all(SfSpace.x14),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SfStatCell(
          value: value,
          label: label,
          valueColor: valueColor,
          delta: delta?.$1,
          deltaColor: delta?.$2,
        ),
      ],
    ),
  );

  /// "▲8" xanh · "▼3" xanh khi giảm là tốt · "—" khi không đổi.
  static (String, Color)? _delta(
    int? value, [
    String suffix = '',
    // ignore: avoid_positional_boolean_parameters — tham số phụ, đọc tại chỗ.
    bool invert = false,
  ]) {
    if (value == null) return null;
    if (value == 0) return ('—', SfColors.textTertiary);
    final good = invert ? value < 0 : value > 0;
    final arrow = value > 0 ? '▲' : '▼';
    return (
      '$arrow${value.abs()}$suffix',
      good ? SfColors.green700 : SfColors.warning,
    );
  }
}

/// Cột giờ lái 4 tuần — cột vượt giới hạn 48h/tuần đổi sang màu cảnh báo.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days, required this.limitMinutes});

  final List<Map<String, dynamic>> days;
  final int limitMinutes;

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

    return SfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SfBarChart(
            values: weekly.map((value) => value.toDouble()).toList(),
            labels: const ['T1', 'T2', 'T3', 'T4'],
            valueLabels: weekly.map(_duration).toList(),
            colors: [
              for (final value in weekly)
                value > limitMinutes ? SfColors.warning : SfColors.green700,
            ],
            maxValue: [
              limitMinutes.toDouble(),
              ...weekly.map((value) => value.toDouble()),
            ].reduce((a, b) => a > b ? a : b),
          ),
          const SizedBox(height: SfSpace.x12),
          Text(
            'Giới hạn ${limitMinutes ~/ 60}h/tuần',
            style: SfType.caption.copyWith(color: p.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Danh sách vi phạm trong tháng.
class _ViolationCard extends StatelessWidget {
  const _ViolationCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final rows = <(String, int, SfStatus)>[
      (
        'Buồn ngủ',
        (data['drowsyAlertCount'] as num?)?.toInt() ??
            (data['alertCount'] as num?)?.toInt() ??
            0,
        SfStatus.warning,
      ),
      (
        'Quá tốc độ',
        (data['speedingCount'] as num?)?.toInt() ?? 0,
        SfStatus.warning,
      ),
      (
        'Lái quá 4 giờ',
        (data['overDrivingCount'] as num?)?.toInt() ?? 0,
        SfStatus.danger,
      ),
      (
        'Ngày không vi phạm',
        (data['alertFreeDays'] as num?)?.toInt() ?? 0,
        SfStatus.good,
      ),
    ];

    return SfCard(
      padding: const EdgeInsets.symmetric(vertical: SfSpace.x4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.border),
            SfListRow(
              title: rows[i].$1,
              leading: SfIconTile(
                icon: rows[i].$3.icon,
                size: 34,
                background: rows[i].$3.tint(p),
                foreground: rows[i].$3.inkOf(p),
              ),
              trailing: Text(
                '${rows[i].$2}',
                style: SfType.stat.copyWith(
                  fontSize: 18,
                  color: rows[i].$3.inkOf(p),
                ),
              ),
            ),
          ],
        ],
      ),
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
      0.0,
      100.0,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: SfSpace.x10),
      child: SfCard(
        emphasis: unlocked ? SfStatus.good : null,
        padding: const EdgeInsets.all(SfSpace.x14),
        child: Row(
          children: [
            SfIconTile(
              icon: unlocked
                  ? Icons.emoji_events_rounded
                  : Icons.lock_outline_rounded,
              radius: SfRadius.pill,
              background: unlocked ? SfColors.warningBg : p.surfaceAlt,
              foreground: unlocked ? SfColors.amber : p.textMuted,
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
                          style: SfType.titleRow.copyWith(
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        unlocked ? 'Đã đạt' : '${progress.round()}%',
                        style: SfType.mono.copyWith(
                          color: unlocked ? SfColors.green700 : p.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data['description']?.toString() ?? '',
                    style: SfType.caption.copyWith(color: p.textMuted),
                  ),
                  if (!unlocked) ...[
                    const SizedBox(height: SfSpace.x8),
                    SfProgressBar(value: progress / 100, height: 6),
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

String _decimal(Object? value) {
  final number = (value as num?)?.toDouble() ?? 0;
  return number == number.roundToDouble()
      ? number.toInt().toString()
      : number.toStringAsFixed(1);
}

/// 214 → "3h34"
String _duration(int minutes) =>
    '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';
