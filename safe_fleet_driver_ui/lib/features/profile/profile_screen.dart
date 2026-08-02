import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';
import '../permissions/permission_setup_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Hồ sơ tài xế'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(SfSpace.x16),
              children: [
                const SfSkeleton(height: 116, radius: SfRadius.card),
                const SizedBox(height: SfSpace.x16),
                SfSkeleton.card(lines: 3),
              ],
            );
          }
          if (snapshot.hasError) {
            return SfEmptyState(
              icon: Icons.person_off_outlined,
              title: 'Không tải được hồ sơ',
              message: '${snapshot.error}\nKéo xuống để thử lại.',
            );
          }
          return _content(snapshot.requireData);
        },
      ),
    );
  }

  Widget _content(Map<String, dynamic> profile) {
    final p = context.sf;
    final driver = Map<String, dynamic>.from(profile['driver'] as Map? ?? {});
    final fullName = profile['fullName']?.toString() ?? 'Tài xế SafeFleet';
    final score = (driver['safetyScore'] as num?)?.round();

    return RefreshIndicator(
      onRefresh: () async {
        final next = ref.read(driverRepositoryProvider).profile();
        setState(() => _future = next);
        await next;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SfSpace.x16,
          SfSpace.x8,
          SfSpace.x16,
          SfSpace.x40 + SfSpace.x40,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(SfSpace.x20),
            decoration: const BoxDecoration(
              color: SfColors.navy,
              borderRadius: SfRadius.cardR,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: SfColors.mint,
                  child: Text(
                    _initials(fullName),
                    style: SfType.titleScreen.copyWith(color: SfColors.navy),
                  ),
                ),
                const SizedBox(width: SfSpace.x16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: SfType.titleScreen.copyWith(
                          color: SfColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: SfSpace.x4),
                      Text(
                        _statusLabel(driver['status']?.toString()),
                        style: SfType.meta.copyWith(
                          color: SfColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      score == null ? '--' : '$score',
                      style: SfType.titleScreen.copyWith(
                        color: score != null && score < 50
                            ? SfColors.dangerHot
                            : SfColors.mint,
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
          ),
          const SizedBox(height: SfSpace.x24),
          const SfSectionLabel('Thông tin liên hệ'),
          const SizedBox(height: SfSpace.x8),
          SfCard(
            child: Column(
              children: [
                _row(p, Icons.phone_outlined, 'Số điện thoại', profile['phone']),
                _row(p, Icons.mail_outline, 'Email', profile['email']),
                _row(
                  p,
                  Icons.home_outlined,
                  'Địa chỉ',
                  driver['address'],
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: SfSpace.x24),
          const SfSectionLabel('Giấy phép lái xe'),
          const SizedBox(height: SfSpace.x8),
          SfCard(
            child: Column(
              children: [
                _row(
                  p,
                  Icons.badge_outlined,
                  'Số GPLX',
                  driver['licenseNumber'],
                ),
                _row(
                  p,
                  Icons.credit_card_outlined,
                  'Hạng bằng',
                  driver['licenseClass'],
                ),
                _row(
                  p,
                  Icons.event_outlined,
                  'Ngày hết hạn',
                  driver['licenseExpiredAt'],
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: SfSpace.x24),
          const SfSectionLabel('Phương tiện và thành tích'),
          const SizedBox(height: SfSpace.x8),
          SfCard(
            child: Column(
              children: [
                _row(
                  p,
                  Icons.local_shipping_outlined,
                  'Xe hiện tại',
                  driver['currentVehiclePlateNumber'],
                ),
                _row(
                  p,
                  Icons.route_outlined,
                  'Tổng chuyến',
                  driver['totalTrips'],
                ),
                _row(
                  p,
                  Icons.warning_amber_rounded,
                  'Tổng cảnh báo',
                  driver['totalAlerts'],
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: SfSpace.x24),
          SfCard(
            onTap: () => Navigator.push(
              context,
              SfSlideRoute<void>(
                builder: (_) => const PermissionSetupScreen(),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: p.accent),
                const SizedBox(width: SfSpace.x16),
                Expanded(
                  child: Text(
                    'Quyền thiết bị',
                    style: SfType.titleCard.copyWith(color: p.textPrimary),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    SfPalette p,
    IconData icon,
    String label,
    Object? value, {
    bool isLast = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : SfSpace.x16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: p.textSecondary, size: 20),
        const SizedBox(width: SfSpace.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: SfType.label.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: SfSpace.x4),
              Text(
                value?.toString().isNotEmpty == true
                    ? value.toString()
                    : 'Chưa cập nhật',
                style: SfType.body.copyWith(
                  color: value?.toString().isNotEmpty == true
                      ? p.textPrimary
                      : p.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String _statusLabel(String? status) => switch (status) {
    'DRIVING' => 'Tài xế · đang trong ca lái',
    'RESTING' => 'Tài xế · đang nghỉ',
    'HIGH_RISK' => 'Tài xế · thuộc nhóm cần theo dõi',
    'SUSPENDED' => 'Tài xế · đang bị tạm dừng',
    'INACTIVE' => 'Tài xế · ngoài ca',
    _ => 'Tài xế · sẵn sàng',
  };

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}
