import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';
import '../../models/driver_models.dart';
import '../camera/cabin_camera_screen.dart';
import '../flood/flood_report_screen.dart';
import '../incidents/sos_screen.dart';
import '../notifications/notifications_screen.dart';
import '../navigation/route_planner_screen.dart';
import '../permissions/permission_setup_screen.dart';
import '../safety/safety_summary_screen.dart';
import '../trips/trip_detail_screen.dart';
import '../trips/trips_today_screen.dart';

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
              padding: const EdgeInsets.fromLTRB(
                SfSpace.x16,
                SfSpace.x8,
                SfSpace.x16,
                SfSpace.x40 + SfSpace.x40,
              ),
              children: [
                _header(snapshot.data),
                const SizedBox(height: SfSpace.x20),
                if (loading)
                  ...[
                    SfSkeleton.card(lines: 4),
                    const SizedBox(height: SfSpace.x12),
                    SfSkeleton.card(),
                  ]
                else if (snapshot.hasError)
                  SfEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Chưa tải được dữ liệu',
                    message:
                        '${snapshot.error}\nKéo xuống để tải lại. Dữ liệu đã lưu vẫn dùng được khi ngoại tuyến.',
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

  // ---- Đầu màn ----

  Widget _header(DriverBootstrap? data) {
    final p = context.sf;
    final driver = data?.driver ?? const <String, dynamic>{};
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandMark(size: 40),
        const SizedBox(width: SfSpace.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(driver['fullName']?.toString()),
                style: SfType.titleScreen.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: SfSpace.x4),
              Text(
                _driverStatusLabel(driver['status']?.toString()),
                style: SfType.meta.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: () => _open(const NotificationsScreen()),
          icon: Badge(
            isLabelVisible: (data?.notifications.length ?? 0) > 0,
            label: Text('${data?.notifications.length ?? 0}'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Tuỳ chọn',
          onSelected: (value) async {
            if (value == 'permissions') _open(const PermissionSetupScreen());
            if (value == 'logout') {
              await ref.read(sessionProvider.notifier).logout();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'permissions', child: Text('Quyền thiết bị')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
          ],
        ),
      ],
    );
  }

  List<Widget> _content(DriverBootstrap data) {
    final trip = data.currentTrip;
    return [
      _HeroTrip(
        trip: trip,
        onOpen: trip == null
            ? null
            : () => _open(
                TripDetailScreen(tripId: (trip['id'] as num).toInt()),
                hero: 'trip-${trip['id']}',
              ),
      ),
      const SizedBox(height: SfSpace.x24),
      const SfSectionLabel('Giờ lái liên tục'),
      const SizedBox(height: SfSpace.x8),
      _drivingHours(data),
      const SizedBox(height: SfSpace.x24),
      SfSectionLabel(
        'Hôm nay',
        trailing: TextButton(
          onPressed: () => _open(const TripsTodayScreen()),
          child: Text('${data.todayTrips.length} chuyến'),
        ),
      ),
      const SizedBox(height: SfSpace.x8),
      _todayBoard(data),
      const SizedBox(height: SfSpace.x24),
      const SfSectionLabel('Thao tác nhanh'),
      const SizedBox(height: SfSpace.x8),
      _quickActions(data),
      const SizedBox(height: SfSpace.x16),
      _syncRow(),
    ];
  }

  // ---- Giờ lái ----

  Widget _drivingHours(DriverBootstrap data) {
    final safety = data.safety;
    final config = data.config;
    return SfCard(
      child: SfDrivingHoursBar(
        continuousMinutes: _int(safety['continuousDrivingMinutes']),
        maxMinutes: _int(config['maxContinuousDrivingMinutes'], 240),
        warning1Minutes: _int(config['warningLevel1Minutes'], 180),
        warning2Minutes: _int(config['warningLevel2Minutes'], 210),
        criticalMinutes: _int(config['criticalWarningMinutes'], 230),
      ),
    );
  }

  // ---- Bảng hôm nay ----

  Widget _todayBoard(DriverBootstrap data) {
    final p = context.sf;
    final safety = data.safety;
    final score = _int(safety['safetyScore']);
    return SfCard(
      onTap: () => _open(SafetySummaryScreen(data: data)),
      child: Row(
        children: [
          SfScoreRing(score: score),
          const SizedBox(width: SfSpace.x20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statLine(
                  'Đã lái hôm nay',
                  '${_int(safety['drivingTimeTodayMinutes'])} phút',
                ),
                const SizedBox(height: SfSpace.x8),
                _statLine('Chuyến đã giao', '${_int(safety['totalTrips'])}'),
                const SizedBox(height: SfSpace.x8),
                _statLine(
                  'Cảnh báo tích luỹ',
                  '${_int(safety['totalAlerts'])}',
                ),
                const SizedBox(height: SfSpace.x12),
                Row(
                  children: [
                    Text(
                      'Xem tổng kết an toàn',
                      style: SfType.meta.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: p.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statLine(String label, String value) {
    final p = context.sf;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: SfType.meta.copyWith(color: p.textSecondary)),
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

  // ---- Thao tác nhanh ----

  Widget _quickActions(DriverBootstrap data) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _quick(
              Icons.map_outlined,
              'Bản đồ an toàn',
              '${data.floodPoints.length} điểm ngập',
              () => _open(const RoutePlannerScreen()),
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: _quick(
              Icons.visibility_outlined,
              'Chống buồn ngủ',
              'Xử lý trên máy',
              () => _open(const CabinCameraScreen()),
            ),
          ),
        ],
      ),
      const SizedBox(height: SfSpace.x12),
      Row(
        children: [
          Expanded(
            child: _quick(
              Icons.route_outlined,
              'Chuyến hôm nay',
              '${data.todayTrips.length} chuyến',
              () => _open(const TripsTodayScreen()),
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: _quick(
              Icons.water_drop_outlined,
              'Báo điểm ngập',
              'Gửi kèm ảnh',
              () => _open(const FloodReportScreen()),
            ),
          ),
        ],
      ),
      const SizedBox(height: SfSpace.x12),
      // SOS đứng riêng, chiếm hết chiều ngang: nó không cùng cấp bậc với
      // bốn thao tác trên.
      SfCard(
        onTap: () => _open(const SosScreen()),
        emphasis: SfStatus.danger,
        child: Row(
          children: [
            const Icon(Icons.sos_rounded, color: SfColors.danger, size: 28),
            const SizedBox(width: SfSpace.x16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gọi cứu hộ khẩn cấp',
                    style: SfType.titleCard.copyWith(color: SfColors.danger),
                  ),
                  const SizedBox(height: SfSpace.x4),
                  Text(
                    'Gửi vị trí hiện tại tới tổng đài, ưu tiên cao nhất',
                    style: SfType.meta.copyWith(
                      color: context.sf.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.sf.textMuted,
            ),
          ],
        ),
      ),
    ],
  );

  Widget _quick(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final p = context.sf;
    return SfCard(
      onTap: onTap,
      padding: const EdgeInsets.all(SfSpace.x16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: SfTouch.min,
            height: SfTouch.min,
            decoration: BoxDecoration(
              color: p.accentTint,
              borderRadius: SfRadius.controlR,
            ),
            child: Icon(icon, color: p.accent),
          ),
          const SizedBox(height: SfSpace.x12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SfType.titleCard.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: SfSpace.x4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SfType.meta.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---- Đồng bộ ----

  Widget _syncRow() {
    final database = ref.read(databaseProvider);
    return FutureBuilder<int>(
      future: database.pendingCount(),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? 0;
        return SfCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SfSpace.x16,
            vertical: SfSpace.x12,
          ),
          child: Row(
            children: [
              SfConnectionChip(online: true, pendingCount: pending),
              const Spacer(),
              TextButton(
                onPressed: pending == 0
                    ? null
                    : () async {
                        await ref.read(syncQueueProvider).syncNow();
                        if (mounted) setState(() {});
                      },
                child: const Text('Đồng bộ ngay'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- Tiện ích ----

  static int _int(Object? value, [int fallback = 0]) => switch (value) {
    final num number => number.round(),
    final String text => int.tryParse(text) ?? fallback,
    _ => fallback,
  };

  String _driverStatusLabel(String? status) => switch (status) {
    'DRIVING' => 'Đang trong ca lái',
    'RESTING' => 'Đang tạm nghỉ',
    'HIGH_RISK' => 'Cần theo dõi an toàn',
    'SUSPENDED' => 'Tài khoản đang bị tạm dừng',
    'INACTIVE' => 'Ngoài ca',
    _ => 'Sẵn sàng nhận chuyến',
  };

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Chào buổi sáng'
        : hour < 18
        ? 'Chào buổi chiều'
        : 'Chào buổi tối';
    final shortName = name?.trim().split(' ').last;
    return shortName == null ? greeting : '$greeting, $shortName';
  }

  void _open(Widget screen, {String? hero}) => Navigator.push(
    context,
    hero == null
        ? SfSlideRoute<void>(builder: (_) => screen)
        : SfMorphRoute<void>(builder: (_) => screen),
  ).then((_) {
    if (mounted) setState(_reload);
  });
}

/// Thẻ chuyến đang chạy — thứ to nhất, tối nhất, đọc được đầu tiên trên màn.
///
/// Nền tối giữa một màn sáng là cách nói "đây là việc đang diễn ra", đồng thời
/// nối liền thị giác với Chế độ lái mà nút này mở ra.
class _HeroTrip extends StatelessWidget {
  const _HeroTrip({required this.trip, this.onOpen});

  final Map<String, dynamic>? trip;
  final VoidCallback? onOpen;

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

    return Container(
      decoration: const BoxDecoration(
        color: SfColors.navy,
        borderRadius: SfRadius.cardR,
      ),
      padding: const EdgeInsets.all(SfSpace.x20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'trip-${data['id']}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    code,
                    style: SfType.mono.copyWith(
                      color: SfColors.mint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _DarkPill(label: _statusLabel(status), status: _status(status)),
            ],
          ),
          const SizedBox(height: SfSpace.x16),
          Text(
            data['startLocation']?.toString() ?? '--',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SfType.body.copyWith(color: SfColors.darkTextSecondary),
          ),
          const SizedBox(height: SfSpace.x4),
          Row(
            children: [
              const Icon(
                Icons.south_east_rounded,
                size: 20,
                color: SfColors.mint,
              ),
              const SizedBox(width: SfSpace.x8),
              Expanded(
                child: Text(
                  data['endLocation']?.toString() ?? '--',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.titleScreen.copyWith(
                    color: SfColors.darkTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x20),
          ClipRRect(
            borderRadius: SfRadius.pillR,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: SfColors.darkSurfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(SfColors.mint),
            ),
          ),
          const SizedBox(height: SfSpace.x8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ ${(progress * 100).round()}%',
                style: SfType.mono.copyWith(color: SfColors.darkTextSecondary),
              ),
              Text(
                data['vehiclePlateNumber']?.toString() ??
                    data['plateNumber']?.toString() ??
                    '',
                style: SfType.mono.copyWith(color: SfColors.darkTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x20),
          SfDriveAction(
            label: _actionLabel(status),
            icon: Icons.navigation_rounded,
            tone: SfColors.teal,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }

  static SfStatus _status(String status) => switch (status) {
    'IN_PROGRESS' => SfStatus.good,
    'RESTING' => SfStatus.pending,
    'DELAYED' => SfStatus.warning,
    'INCIDENT' => SfStatus.danger,
    _ => SfStatus.pending,
  };

  static String _statusLabel(String status) => switch (status) {
    'ASSIGNED' => 'Chờ nhận',
    'ACCEPTED' => 'Đã nhận',
    'IN_PROGRESS' => 'Đang chạy',
    'RESTING' => 'Đang nghỉ',
    'DELAYED' => 'Trễ giờ',
    'INCIDENT' => 'Có sự cố',
    'COMPLETED' => 'Hoàn thành',
    _ => status.isEmpty ? '--' : status,
  };

  static String _actionLabel(String status) => switch (status) {
    'ASSIGNED' => 'Xem và nhận chuyến',
    'ACCEPTED' => 'Chuẩn bị khởi hành',
    'RESTING' => 'Tiếp tục chuyến',
    _ => 'Mở chế độ lái',
  };
}

/// Pill trạng thái đặt trên nền tối của thẻ hero.
class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.label, required this.status});

  final String label;
  final SfStatus status;

  @override
  Widget build(BuildContext context) {
    final ink = status.inkOnDark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SfSpace.x12,
        vertical: SfSpace.x4 + 2,
      ),
      decoration: BoxDecoration(
        color: SfColors.darkSurfaceAlt,
        borderRadius: SfRadius.pillR,
        border: Border.all(color: ink.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 15, color: ink),
          const SizedBox(width: SfSpace.x4),
          Text(
            label,
            style: SfType.meta.copyWith(
              color: ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
