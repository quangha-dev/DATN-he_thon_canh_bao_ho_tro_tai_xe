import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/widgets/ui.dart';

/// Mỗi quyền nói rõ hai điều: dùng để làm gì, và mất gì nếu từ chối.
class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen> {
  Map<Permission, PermissionStatus> _statuses = {};
  bool _busy = false;

  static const permissions = [
    Permission.locationWhenInUse,
    Permission.locationAlways,
    Permission.camera,
    Permission.microphone,
    Permission.notification,
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final result = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      result[permission] = await permission.status;
    }
    if (mounted) setState(() => _statuses = result);
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    final foregroundLocation = await Permission.locationWhenInUse.request();
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.notification,
    ].request();
    statuses[Permission.locationWhenInUse] = foregroundLocation;
    if (foregroundLocation.isGranted) {
      statuses[Permission.locationAlways] = await Permission.locationAlways
          .request();
    } else {
      statuses[Permission.locationAlways] =
          await Permission.locationAlways.status;
    }
    _statuses = statuses;
    if (mounted) setState(() => _busy = false);
  }

  int get _grantedCount =>
      permissions.where((p) => _statuses[p]?.isGranted == true).length;

  @override
  Widget build(BuildContext context) => SfSubScreen(
    title: 'Quyền & riêng tư',
    subtitle: '$_grantedCount/${permissions.length} quyền đã cấp',
    bottomBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SfPrimaryAction(
          label: 'Cấp các quyền cần thiết',
          icon: Icons.shield_rounded,
          busy: _busy,
          onPressed: _request,
        ),
        TextButton(
          onPressed: openAppSettings,
          child: const Text('Mở cài đặt hệ thống'),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SfInfoBox(
          icon: Icons.lock_rounded,
          text:
              'SafeFleet chỉ dùng quyền khi đang trong ca lái. '
              'Không có quyền nào chạy ngầm ngoài giờ làm.',
        ),
        const SizedBox(height: SfSpace.x14),
        _permission(
          permission: Permission.locationWhenInUse,
          icon: Icons.my_location_rounded,
          title: 'Vị trí khi đang lái',
          why: 'Dẫn đường, gửi telemetry và định vị khi bạn gọi cứu hộ.',
          ifDenied: 'Không theo dõi ngoài giờ làm. '
              'Nếu từ chối: không dẫn đường được và SOS không kèm toạ độ.',
          mandatory: true,
        ),
        _permission(
          permission: Permission.locationAlways,
          icon: Icons.location_searching_rounded,
          title: 'Vị trí khi chạy nền',
          why: 'Điều hành vẫn thấy xe khi bạn chuyển sang ứng dụng khác.',
          ifDenied:
              'Vị trí xe đứng yên trên màn điều hành khi bạn thoát app.',
        ),
        _permission(
          permission: Permission.camera,
          icon: Icons.camera_alt_rounded,
          title: 'Camera cabin',
          why: 'Video không rời khỏi điện thoại — mô hình chạy ngay trên máy.',
          ifDenied: 'Không có cảnh báo buồn ngủ.',
          mandatory: true,
        ),
        _permission(
          permission: Permission.microphone,
          icon: Icons.mic_rounded,
          title: 'Micro',
          why: 'Chỉ ghi âm khi bạn nhấn giữ nút nói.',
          ifDenied: 'Chỉ dùng được trợ lý bằng cách gõ chữ.',
        ),
        _permission(
          permission: Permission.notification,
          icon: Icons.notifications_active_rounded,
          title: 'Thông báo nổi khi đang lái',
          why: 'Nhận chuyến mới, cảnh báo ngập và phản hồi SOS.',
          ifDenied: 'Bạn có thể bỏ lỡ chuyến được giao và cảnh báo ngập.',
          mandatory: true,
        ),
        const SizedBox(height: SfSpace.x8),
        Text(
          'Dữ liệu chuyến được giữ 90 ngày theo quy định của doanh nghiệp '
          'vận tải.',
          textAlign: TextAlign.center,
          style: SfType.caption.copyWith(color: context.sf.textMuted),
        ),
      ],
    ),
  );

  /// Thẻ quyền chưa cấp mà lại bắt buộc thì chuyển sang nền vàng và có nút
  /// "Cấp quyền" ngay trên thẻ — không bắt tài xế đi tìm.
  Widget _permission({
    required Permission permission,
    required IconData icon,
    required String title,
    required String why,
    required String ifDenied,
    bool mandatory = false,
  }) {
    final p = context.sf;
    final granted = _statuses[permission]?.isGranted == true;
    final needsAttention = mandatory && !granted;

    return Padding(
      padding: const EdgeInsets.only(bottom: SfSpace.x10),
      child: SfCard(
        padding: const EdgeInsets.all(SfSpace.x14),
        emphasis: needsAttention ? SfStatus.warning : null,
        background: needsAttention ? SfColors.warningBg : null,
        borderWidth: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SfIconTile(
                  icon: icon,
                  background: granted
                      ? SfColors.green100
                      : (needsAttention ? SfColors.warningBg : p.surfaceAlt),
                  foreground: granted
                      ? SfColors.green700
                      : (needsAttention ? SfColors.warning : p.textMuted),
                ),
                const SizedBox(width: SfSpace.x12),
                Expanded(
                  child: Text(
                    title,
                    style: SfType.titleRow.copyWith(
                      color: needsAttention
                          ? SfColors.warningInk
                          : p.textPrimary,
                    ),
                  ),
                ),
                SfStatusPill(
                  granted ? 'Đã cấp' : 'Chưa cấp',
                  status: granted
                      ? SfStatus.good
                      : (mandatory ? SfStatus.warning : SfStatus.pending),
                ),
              ],
            ),
            const SizedBox(height: SfSpace.x10),
            Text(
              why,
              style: SfType.caption.copyWith(
                color: needsAttention ? SfColors.warningInk : p.textSecondary,
              ),
            ),
            if (!granted) ...[
              const SizedBox(height: SfSpace.x8),
              Text(
                ifDenied,
                style: SfType.caption.copyWith(color: SfColors.warning),
              ),
              if (mandatory) ...[
                const SizedBox(height: SfSpace.x12),
                SizedBox(
                  height: SfTouch.min,
                  child: FilledButton(
                    onPressed: () async {
                      await permission.request();
                      await _refresh();
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, SfTouch.min),
                    ),
                    child: const Text('Cấp quyền'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
