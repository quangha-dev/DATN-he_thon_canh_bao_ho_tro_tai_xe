import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/agent/agent_conversation_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/ui.dart';
import '../camera/cabin_camera_screen.dart';
import '../documents/driving_log_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../permissions/permission_setup_screen.dart';

/// Hồ sơ tài xế — tab thứ năm.
///
/// Header gradient chứa danh tính; bên dưới là giấy tờ, danh sách cài đặt,
/// tình trạng máy chủ và nút đăng xuất.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(driverRepositoryProvider).profile();
  }

  Future<void> _refresh() async {
    final next = ref.read(driverRepositoryProvider).profile();
    setState(() => _future = next);
    await next;
  }

  String get _serverLabel {
    final uri = Uri.tryParse(AppConfig.defaultApiUrl);
    if (uri == null || uri.host.isEmpty) return AppConfig.defaultApiUrl;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.sf.bg,
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SfEmptyState(
            icon: Icons.person_off_rounded,
            title: 'Không tải được hồ sơ',
            message: '${snapshot.error}\nKéo xuống để thử lại.',
          );
        }
        final profile = snapshot.data ?? const <String, dynamic>{};
        final loading = !snapshot.hasData;
        final driver = Map<String, dynamic>.from(
          profile['driver'] as Map? ?? const {},
        );
        final fullName =
            profile['fullName']?.toString() ?? 'Tài xế SafeFleet';

        return Column(
          children: [
            _header(fullName, driver),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: SfSpace.screen,
                  children: loading
                      ? [
                          const SizedBox(height: SfSpace.x8),
                          SfSkeleton.card(lines: 3),
                          const SizedBox(height: SfSpace.x12),
                          SfSkeleton.card(),
                        ]
                      : _content(profile, driver),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  // ---- Header gradient ----

  Widget _header(String fullName, Map<String, dynamic> driver) {
    final code = driver['driverCode']?.toString();
    final branch = driver['branchName']?.toString() ?? driver['branch']?.toString();
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SfGradients.header),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SfSpace.x16,
            SfSpace.x18,
            SfSpace.x16,
            SfSpace.x20,
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SfColors.onAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(SfRadius.hero),
                ),
                child: Text(
                  _initials(fullName),
                  style: SfType.titleScreen.copyWith(
                    color: SfColors.onAccent,
                  ),
                ),
              ),
              const SizedBox(width: SfSpace.x16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SfType.titleScreen.copyWith(
                        color: SfColors.onAccent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (code != null && code.isNotEmpty) 'Mã $code',
                        if (branch != null && branch.isNotEmpty)
                          'Chi nhánh $branch',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SfType.caption.copyWith(
                        color: SfColors.green300,
                      ),
                    ),
                    const SizedBox(height: SfSpace.x10),
                    SfStatusPill.onHero(
                      _statusLabel(driver['status']?.toString()),
                      icon: Icons.verified_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Thân màn ----

  List<Widget> _content(
    Map<String, dynamic> profile,
    Map<String, dynamic> driver,
  ) {
    final p = context.sf;
    return [
      const SizedBox(height: SfSpace.x4),
      const SfSectionLabel('Giấy tờ'),
      const SizedBox(height: SfSpace.x10),
      _licenceCard(driver),
      const SizedBox(height: SfSpace.x10),
      _vehicleCard(driver),
      const SizedBox(height: SfSpace.x18),
      const SfSectionLabel('Cài đặt'),
      const SizedBox(height: SfSpace.x10),
      _wakeCard(),
      const SizedBox(height: SfSpace.x10),
      SfCard(
        padding: const EdgeInsets.symmetric(vertical: SfSpace.x4),
        child: Column(
          children: [
            SfListRow(
              icon: Icons.notifications_rounded,
              title: 'Thông báo',
              showChevron: true,
              trailing: _Badge(count: _int(driver['unreadNotifications'])),
              onTap: () => _open(const NotificationsScreen()),
            ),
            Divider(height: 1, color: p.border),
            SfListRow(
              icon: Icons.shield_rounded,
              title: 'Quyền & riêng tư',
              subtitle: 'Kiểm tra các quyền app đang dùng',
              showChevron: true,
              onTap: () => _open(const PermissionSetupScreen()),
            ),
            Divider(height: 1, color: p.border),
            SfListRow(
              icon: Icons.visibility_rounded,
              title: 'Cài đặt giám sát tỉnh táo',
              subtitle: 'Xử lý trên máy · không gửi video lên server',
              showChevron: true,
              onTap: () => _open(const CabinCameraScreen()),
            ),
            Divider(height: 1, color: p.border),
            SfListRow(
              icon: Icons.receipt_long_rounded,
              title: 'Nhật trình phiếu',
              subtitle: 'Xem phiếu đã lưu và xuất Excel',
              showChevron: true,
              onTap: () => _open(const DrivingLogListScreen()),
            ),
          ],
        ),
      ),
      const SizedBox(height: SfSpace.x18),
      const SfSectionLabel('Liên hệ'),
      const SizedBox(height: SfSpace.x10),
      SfCard(
        padding: const EdgeInsets.symmetric(vertical: SfSpace.x4),
        child: Column(
          children: [
            SfListRow(
              icon: Icons.phone_rounded,
              title: _text(profile['phone']),
              subtitle: 'Số điện thoại',
            ),
            Divider(height: 1, color: p.border),
            SfListRow(
              icon: Icons.mail_rounded,
              title: _text(profile['email']),
              subtitle: 'Email',
            ),
          ],
        ),
      ),
      const SizedBox(height: SfSpace.x18),
      _serverCard(),
      const SizedBox(height: SfSpace.x18),
      _logoutButton(),
      const SizedBox(height: SfSpace.x14),
      Text(
        'SafeFleet Driver v1.0.0 · máy chủ $_serverLabel',
        textAlign: TextAlign.center,
        style: SfType.caption.copyWith(color: p.textMuted),
      ),
    ];
  }

  Widget _licenceCard(Map<String, dynamic> driver) {
    final expiry = driver['licenseExpiredAt']?.toString();
    final expired = _isExpired(expiry);
    return SfCard(
      padding: const EdgeInsets.all(SfSpace.x14),
      child: SfListRow(
        padding: EdgeInsets.zero,
        icon: Icons.badge_rounded,
        title:
            'GPLX hạng ${_text(driver['licenseClass'])} · '
            '${_text(driver['licenseNumber'])}',
        subtitle: expiry == null || expiry.isEmpty
            ? 'Chưa cập nhật hạn'
            : 'Hết hạn ${_date(expiry)}',
        trailing: SfStatusPill(
          expired ? 'Hết hạn' : 'Còn hạn',
          status: expired ? SfStatus.danger : SfStatus.good,
        ),
      ),
    );
  }

  Widget _vehicleCard(Map<String, dynamic> driver) {
    final plate = driver['currentVehiclePlateNumber']?.toString();
    return SfCard(
      padding: const EdgeInsets.all(SfSpace.x14),
      child: SfListRow(
        padding: EdgeInsets.zero,
        icon: Icons.local_shipping_rounded,
        title: plate == null || plate.isEmpty ? 'Chưa gán xe' : plate,
        subtitle: [
          if (driver['vehicleType'] != null) '${driver['vehicleType']}',
          'Tổng ${_int(driver['totalTrips'])} chuyến',
        ].join(' · '),
        trailing: SfStatusPill(
          '${_int(driver['totalAlerts'])} cảnh báo',
          status: _int(driver['totalAlerts']) > 0
              ? SfStatus.warning
              : SfStatus.good,
        ),
      ),
    );
  }

  /// Công tắc nghe nền.
  ///
  /// Micro chỉ chạy khi app đang mở; tắt app là tắt hẳn. Nói rõ điều đó ngay
  /// trên thẻ vì đây là quyền nhạy cảm nhất tài xế cấp cho ứng dụng.
  Widget _wakeCard() {
    final enabled = ref.watch(
      agentConversationProvider.select((state) => state.wakeEnabled),
    );
    final listening = ref.watch(
      agentConversationProvider.select((state) => state.listening),
    );
    final p = context.sf;

    return SfCard(
      padding: const EdgeInsets.all(SfSpace.x14),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: enabled ? SfColors.green700 : p.textMuted,
            size: 22,
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gọi trợ lý bất cứ lúc nào',
                  style: SfType.titleRow.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  enabled
                      ? (listening
                            ? 'Đang nghe · nói "Hey SafeFleet" để ra lệnh'
                            : 'Đã bật · micro chỉ chạy khi app đang mở')
                      : 'Đang tắt · phải chạm nút micro mới nói được',
                  style: SfType.caption.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (value) => unawaited(
              ref
                  .read(agentConversationProvider.notifier)
                  .setWakeEnabled(value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serverCard() => SfCard(
    padding: const EdgeInsets.all(SfSpace.x14),
    child: Row(
      children: [
        const SfPulseDot(color: SfColors.green700),
        const SizedBox(width: SfSpace.x12),
        Expanded(
          child: Text(
            'Máy chủ $_serverLabel · Kết nối tốt',
            style: SfType.caption.copyWith(color: context.sf.textSecondary),
          ),
        ),
      ],
    ),
  );

  Widget _logoutButton() => SfPressable(
    onTap: () => ref.read(sessionProvider.notifier).logout(),
    child: Container(
      height: SfTouch.primaryHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SfColors.dangerBg,
        borderRadius: SfRadius.controlLgR,
        border: Border.all(color: SfColors.dangerBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.logout_rounded, size: 20, color: SfColors.danger),
          const SizedBox(width: SfSpace.x8),
          Text(
            'Đăng xuất',
            style: SfType.titleCardSm.copyWith(color: SfColors.danger),
          ),
        ],
      ),
    ),
  );

  // ---- Tiện ích ----

  void _open(Widget screen) => Navigator.push<void>(
    context,
    SfSlideRoute<void>(builder: (_) => screen),
  );

  static int _int(Object? value) => switch (value) {
    final num number => number.round(),
    final String text => int.tryParse(text) ?? 0,
    _ => 0,
  };

  static String _text(Object? value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? 'Chưa cập nhật' : text;
  }

  /// "2028-07-27" → "27/07/2028"
  static String _date(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  static bool _isExpired(String? value) {
    if (value == null || value.isEmpty) return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.isBefore(DateTime.now());
  }

  String _statusLabel(String? status) => switch (status) {
    'DRIVING' => 'Đang trong ca lái',
    'RESTING' => 'Đang nghỉ',
    'HIGH_RISK' => 'Cần theo dõi',
    'SUSPENDED' => 'Tạm dừng',
    'INACTIVE' => 'Ngoài ca',
    _ => 'Đang hoạt động',
  };

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'TX';
    return parts
        .take(2)
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .join();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: SfColors.danger,
        borderRadius: SfRadius.pillR,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: SfType.chip.copyWith(
          color: SfColors.onAccent,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
