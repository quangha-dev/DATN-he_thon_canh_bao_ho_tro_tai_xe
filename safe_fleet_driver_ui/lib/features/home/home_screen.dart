import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';
import '../../models/driver_models.dart';
import '../camera/cabin_camera_screen.dart';
import '../documents/driving_log_list_screen.dart';
import '../flood/flood_report_screen.dart';
import '../incidents/sos_screen.dart';
import '../notifications/notifications_screen.dart';
import '../navigation/route_planner_screen.dart';
import '../navigation/widgets/navigation_resume_card.dart';
import '../safety/safety_summary_screen.dart';
import '../trips/trip_detail_screen.dart';
import '../trips/trips_today_screen.dart';

/// Trang Nhà — màn quan trọng nhất.
///
/// Thứ tự khối từ trên xuống: header → thẻ chuyến đang chạy → giờ lái liên tục
/// → tổng kết hôm nay → thao tác nhanh → SOS → trạng thái đồng bộ.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<DriverBootstrap> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(driverRepositoryProvider).bootstrap();
  }

  Future<void> _refresh() async {
    setState(_reload);
    ref.invalidate(activeNavigationProvider);
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.sf.bg,
    body: SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<DriverBootstrap>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            return ListView(
              padding: SfSpace.screen,
              children: [
                _header(snapshot.data),
                const SizedBox(height: SfSpace.x18),
                // Phiên dẫn đường đang mở luôn đứng trên cùng: đó là việc tài
                // xế đang làm dở, không phải một mục trong danh sách.
                const NavigationResumeCard(),
                if (loading) ...[
                  SfSkeleton.card(lines: 4),
                  const SizedBox(height: SfSpace.x12),
                  SfSkeleton.card(),
                ] else if (snapshot.hasError)
                  SfEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Chưa tải được dữ liệu',
                    message:
                        '${snapshot.error}\nKéo xuống để tải lại. '
                        'Dữ liệu đã lưu vẫn dùng được khi ngoại tuyến.',
                  )
                else
                  ..._content(snapshot.requireData),
              ],
            );
          },
        ),
      ),
    ),
  );

  // ---- 1. Header ----

  Widget _header(DriverBootstrap? data) {
    final p = context.sf;
    final driver = data?.driver ?? const <String, dynamic>{};
    final unread = data?.notifications.length ?? 0;
    return Row(
      children: [
        const BrandMark(size: 44),
        const SizedBox(width: SfSpace.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _greeting(driver['fullName']?.toString()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SfType.titleScreen.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const SfPulseDot(color: SfColors.green700),
                  const SizedBox(width: SfSpace.x8),
                  Flexible(
                    child: Text(
                      _statusLine(data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SfType.caption.copyWith(color: p.textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: SfSpace.x8),
        SfIconButton(
          icon: Icons.document_scanner_rounded,
          tooltip: 'Quét phiếu',
          onTap: () => _open(const DrivingLogListScreen()),
        ),
        const SizedBox(width: SfSpace.x8),
        SfIconButton(
          icon: Icons.notifications_rounded,
          tooltip: 'Thông báo',
          badge: unread,
          onTap: () => _open(const NotificationsScreen()),
        ),
      ],
    );
  }

  /// "Đang lái · xe 30H-100.01"
  String _statusLine(DriverBootstrap? data) {
    final driver = data?.driver ?? const <String, dynamic>{};
    final label = _driverStatusLabel(driver['status']?.toString());
    final plate =
        data?.currentTrip?['vehiclePlateNumber']?.toString() ??
        data?.currentTrip?['plateNumber']?.toString();
    return plate == null || plate.isEmpty ? label : '$label · xe $plate';
  }

  List<Widget> _content(DriverBootstrap data) {
    final trip = data.currentTrip;
    return [
      _HeroTrip(
        trip: trip,
        onDrive: trip == null
            ? null
            : () => _open(
                TripDetailScreen(tripId: (trip['id'] as num).toInt()),
                hero: 'trip-${trip['id']}',
              ),
        onDetail: trip == null
            ? null
            : () =>
                  _open(TripDetailScreen(tripId: (trip['id'] as num).toInt())),
      ),
      const SizedBox(height: SfSpace.x18),
      _drivingHours(data),
      const SizedBox(height: SfSpace.x18),
      const SfSectionLabel('Hôm nay'),
      const SizedBox(height: SfSpace.x10),
      _todayBoard(data),
      const SizedBox(height: SfSpace.x18),
      const SfSectionLabel('Thao tác nhanh'),
      const SizedBox(height: SfSpace.x10),
      _quickActions(data),
      const SizedBox(height: SfSpace.x14),
      _sosBlock(),
      const SizedBox(height: SfSpace.x14),
      _SyncCard(onSynced: () => setState(() {})),
    ];
  }

  // ---- 3. Giờ lái liên tục ----

  Widget _drivingHours(DriverBootstrap data) {
    final safety = data.safety;
    final config = data.config;
    return SfCard(
      child: SfDrivingHoursBar(
        continuousMinutes: _int(safety['continuousDrivingMinutes']),
        maxMinutes: _int(config['maxContinuousDrivingMinutes'], 240),
        remindMinutes: _int(config['warningLevel1Minutes'], 180),
        warnMinutes: _int(config['warningLevel2Minutes'], 210),
        criticalMinutes: _int(config['criticalWarningMinutes'], 230),
      ),
    );
  }

  // ---- 4. Hôm nay ----

  Widget _todayBoard(DriverBootstrap data) {
    final p = context.sf;
    final safety = data.safety;
    final alerts = _int(safety['totalAlerts']);
    return SfCard(
      onTap: () => _open(SafetySummaryScreen(data: data)),
      child: Row(
        children: [
          SfScoreRing(
            score: _int(safety['safetyScore']),
            size: 78,
            caption: 'ĐIỂM',
          ),
          const SizedBox(width: SfSpace.x18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statLine(
                  'Đã lái',
                  _duration(_int(safety['drivingTimeTodayMinutes'])),
                ),
                const SizedBox(height: SfSpace.x8),
                _statLine('Chuyến đã giao', '${_int(safety['totalTrips'])}'),
                const SizedBox(height: SfSpace.x8),
                _statLine(
                  'Cảnh báo',
                  '$alerts',
                  valueColor: alerts > 0 ? SfColors.warning : null,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 22, color: p.textMuted),
        ],
      ),
    );
  }

  Widget _statLine(String label, String value, {Color? valueColor}) {
    final p = context.sf;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: SfType.caption.copyWith(color: p.textMuted)),
        Text(
          value,
          style: SfType.mono.copyWith(
            color: valueColor ?? p.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ---- 5. Thao tác nhanh ----

  Widget _quickActions(DriverBootstrap data) {
    final floods = data.floodPoints.length;
    final today = data.todayTrips.length;
    final running = data.todayTrips
        .where((trip) => trip['status'] == 'IN_PROGRESS')
        .length;
    final waiting = today - running;

    final tiles = <Widget>[
      SfQuickAction(
        icon: Icons.map_rounded,
        title: 'Bản đồ an toàn',
        subtitle: '$floods điểm ngập gần tuyến',
        onTap: () => _open(const RoutePlannerScreen()),
      ),
      SfQuickAction(
        icon: Icons.visibility_rounded,
        title: 'Chống buồn ngủ',
        subtitle: 'Xử lý trên máy · đang bật',
        onTap: () => _open(const CabinCameraScreen()),
      ),
      SfQuickAction(
        icon: Icons.route_rounded,
        title: 'Chuyến hôm nay',
        subtitle: '$waiting chưa đi · $running đang chạy',
        onTap: () => _open(const TripsTodayScreen()),
      ),
      SfQuickAction(
        icon: Icons.add_road_rounded,
        title: 'Báo tình trạng đường',
        subtitle: 'Ngập nước hoặc kẹt xe',
        iconBackground: SfColors.infoBg,
        iconForeground: SfColors.info,
        onTap: () => _open(const FloodReportScreen()),
      ),
      SfQuickAction(
        icon: Icons.document_scanner_rounded,
        title: 'Quét phiếu',
        subtitle: 'Chụp và OCR ngay',
        onTap: () => _open(const DrivingLogListScreen()),
      ),
      SfQuickAction(
        icon: Icons.receipt_long_rounded,
        title: 'Nhật trình phiếu',
        subtitle: 'Xem và xuất Excel',
        onTap: () => _open(const DrivingLogListScreen()),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: SfSpace.x12,
      mainAxisSpacing: SfSpace.x12,
      childAspectRatio: 1.32,
      children: tiles,
    );
  }

  // ---- 6. SOS ----

  Widget _sosBlock() => SfCard(
    onTap: () => _open(const SosScreen()),
    emphasis: SfStatus.danger,
    tinted: true,
    borderWidth: 1,
    padding: const EdgeInsets.all(SfSpace.x14),
    child: Row(
      children: [
        const SfIconTile(
          icon: Icons.sos_rounded,
          size: 44,
          background: SfColors.danger,
          foreground: SfColors.onAccent,
        ),
        const SizedBox(width: SfSpace.x14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cứu hộ khẩn cấp',
                style: SfType.titleRow.copyWith(color: SfColors.dangerStrong),
              ),
              const SizedBox(height: 2),
              Text(
                'Giữ 2 giây để gọi điều hành · ưu tiên cao nhất',
                style: SfType.caption.copyWith(color: SfColors.danger),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ---- Tiện ích ----

  static int _int(Object? value, [int fallback = 0]) => switch (value) {
    final num number => number.round(),
    final String text => int.tryParse(text) ?? fallback,
    _ => fallback,
  };

  /// 214 → "3h34"
  static String _duration(int minutes) =>
      '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';

  String _driverStatusLabel(String? status) => switch (status) {
    'DRIVING' => 'Đang lái',
    'RESTING' => 'Đang tạm nghỉ',
    'HIGH_RISK' => 'Cần theo dõi an toàn',
    'SUSPENDED' => 'Tài khoản đang bị tạm dừng',
    'INACTIVE' => 'Ngoài ca',
    _ => 'Sẵn sàng nhận chuyến',
  };

  String _greeting(String? name) {
    final shortName = name?.trim().split(' ').last;
    return shortName == null || shortName.isEmpty
        ? 'Chào bạn'
        : 'Chào $shortName';
  }

  void _open(Widget screen, {String? hero}) =>
      Navigator.push(
        context,
        hero == null
            ? SfSlideRoute<void>(builder: (_) => screen)
            : SfMorphRoute<void>(builder: (_) => screen),
      ).then((_) {
        if (mounted) setState(_reload);
      });
}

/// Thẻ chuyến đang chạy — thứ to nhất, đọc được đầu tiên trên màn.
///
/// Gradient xanh giữa một màn sáng là cách nói "đây là việc đang diễn ra",
/// đồng thời nối liền thị giác với Chế độ lái mà nút này mở ra.
class _HeroTrip extends StatelessWidget {
  const _HeroTrip({required this.trip, this.onDrive, this.onDetail});

  final Map<String, dynamic>? trip;
  final VoidCallback? onDrive;
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final data = trip;

    if (data == null) {
      return SfCard(
        padding: const EdgeInsets.symmetric(
          horizontal: SfSpace.x20,
          vertical: SfSpace.x32,
        ),
        child: Column(
          children: [
            Icon(Icons.event_available_rounded, size: 40, color: p.textMuted),
            const SizedBox(height: SfSpace.x12),
            Text(
              'Chưa có chuyến đang chạy',
              style: SfType.titleCard.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: SfSpace.x4),
            Text(
              'Chuyến mới do điều phối giao sẽ hiện ở đây.',
              textAlign: TextAlign.center,
              style: SfType.meta.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      );
    }

    final status = data['status']?.toString() ?? '';
    final progress = switch (data['progress']) {
      final num value => (value / 100).clamp(0.0, 1.0).toDouble(),
      _ => 0.0,
    };
    final code = data['tripCode']?.toString() ?? '--';
    final highRisk =
        data['riskLevel']?.toString() == 'HIGH' ||
        status == 'INCIDENT' ||
        status == 'DELAYED';

    return SfHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SfStatusPill.onHero(_statusLabel(status)),
              if (highRisk) ...[
                const SizedBox(width: SfSpace.x8),
                const SfStatusPill.amber('Rủi ro cao'),
              ],
              const Spacer(),
              Hero(
                tag: 'trip-${data['id']}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    code,
                    style: SfType.mono.copyWith(
                      color: SfColors.green300,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x18),
          SfTimeline(
            onHero: true,
            entries: [
              SfTimelineEntry(
                title: data['startLocation']?.toString() ?? '--',
                subtitle: _startMeta(data),
              ),
              SfTimelineEntry(
                title: data['endLocation']?.toString() ?? '--',
                subtitle: _endMeta(data),
                isSquare: true,
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x18),
          SfProgressBar(
            value: progress,
            gradient: SfGradients.progressOnHero,
            trackColor: SfColors.onAccent.withValues(alpha: 0.22),
          ),
          const SizedBox(height: SfSpace.x18),
          Row(
            children: [
              Expanded(
                child: SfPressable(
                  onTap: onDrive,
                  child: Container(
                    height: SfTouch.primaryHeight,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: SfColors.onAccent,
                      borderRadius: SfRadius.controlLgR,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.navigation_rounded,
                          size: 20,
                          color: SfColors.green700,
                        ),
                        const SizedBox(width: SfSpace.x8),
                        Text(
                          _actionLabel(status),
                          style: SfType.titleCardSm.copyWith(
                            color: SfColors.green700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SfSpace.x12),
              SfIconButton(
                icon: Icons.description_rounded,
                size: SfTouch.primaryHeight,
                onHero: true,
                tooltip: 'Chi tiết chuyến',
                onTap: onDetail,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String? _startMeta(Map<String, dynamic> data) {
    final time = data['startTime']?.toString();
    return time == null || time.isEmpty
        ? 'đã xuất phát'
        : 'Khởi hành ${_time(time)} · đã xuất phát';
  }

  static String? _endMeta(Map<String, dynamic> data) {
    final eta =
        data['estimatedEndTime']?.toString() ?? data['endTime']?.toString();
    final remaining = data['remainingDistanceKm'] ?? data['distanceKm'];
    return [
      if (eta != null && eta.isNotEmpty) 'Dự kiến ${_time(eta)}',
      if (remaining is num) 'còn ${remaining.toStringAsFixed(1)} km',
    ].join(' · ');
  }

  /// "2026-07-27T06:30:00" → "06:30"
  static String _time(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  static String _statusLabel(String status) => switch (status) {
    'ASSIGNED' => 'Chờ nhận',
    'ACCEPTED' => 'Đã nhận',
    'IN_PROGRESS' => 'Đang thực hiện',
    'RESTING' => 'Đang nghỉ',
    'DELAYED' => 'Trễ giờ',
    'INCIDENT' => 'Có sự cố',
    'COMPLETED' => 'Hoàn thành',
    _ => status.isEmpty ? '--' : status,
  };

  static String _actionLabel(String status) => switch (status) {
    'ASSIGNED' => 'Xem và nhận chuyến',
    'ACCEPTED' => 'Chuẩn bị khởi hành',
    'RESTING' => 'Tiếp tục lái',
    _ => 'Tiếp tục lái',
  };
}

/// Trạng thái đồng bộ: chờ → đang gửi → đã xong, đổi icon, màu và chữ.
class _SyncCard extends ConsumerStatefulWidget {
  const _SyncCard({required this.onSynced});

  final VoidCallback onSynced;

  @override
  ConsumerState<_SyncCard> createState() => _SyncCardState();
}

enum _SyncPhase { idle, sending, done }

class _SyncCardState extends ConsumerState<_SyncCard> {
  _SyncPhase _phase = _SyncPhase.idle;
  late Future<int> _pending;

  @override
  void initState() {
    super.initState();
    _pending = ref.read(databaseProvider).pendingCount();
  }

  Future<void> _sync() async {
    setState(() => _phase = _SyncPhase.sending);
    try {
      await ref.read(syncQueueProvider).syncNow();
    } catch (_) {
      // Ngoại tuyến là trạng thái bình thường — hàng đợi vẫn còn đó.
    }
    if (!mounted) return;
    setState(() {
      _phase = _SyncPhase.done;
      _pending = ref.read(databaseProvider).pendingCount();
    });
    widget.onSynced();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
    future: _pending,
    builder: (context, snapshot) {
      final pending = snapshot.data ?? 0;
      final (icon, ink, text) = switch (_phase) {
        _SyncPhase.sending => (
          Icons.sync_rounded,
          SfColors.warning,
          'Đang gửi lên server…',
        ),
        _SyncPhase.done => (
          Icons.cloud_done_rounded,
          SfColors.green700,
          'Đã đồng bộ xong · Lần cuối: vừa xong',
        ),
        _SyncPhase.idle when pending == 0 => (
          Icons.cloud_done_rounded,
          SfColors.green700,
          'Không có mục nào chờ đồng bộ',
        ),
        _ => (
          Icons.cloud_upload_rounded,
          SfColors.warning,
          '$pending mục đang chờ đồng bộ',
        ),
      };

      return SfCard(
        padding: const EdgeInsets.all(SfSpace.x14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ink),
            const SizedBox(width: SfSpace.x10),
            Expanded(
              child: Text(text, style: SfType.caption.copyWith(color: ink)),
            ),
            if (pending > 0 && _phase != _SyncPhase.sending)
              TextButton(onPressed: _sync, child: const Text('Đồng bộ')),
          ],
        ),
      );
    },
  );
}
