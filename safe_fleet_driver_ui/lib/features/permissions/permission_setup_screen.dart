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
  Widget build(BuildContext context) {
    final p = context.sf;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: const Text('Quyền thiết bị')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SfSpace.x16,
          SfSpace.x8,
          SfSpace.x16,
          SfSpace.x32,
        ),
        children: [
          SfScreenTitle(
            title: 'Bật lớp bảo vệ chuyến đi',
            subtitle:
                'SafeFleet chỉ dùng quyền khi đang trong ca lái. Không có quyền nào chạy ngầm ngoài giờ làm.',
            trailing: SfStatusPill(
              '$_grantedCount/${permissions.length}',
              status: _grantedCount == permissions.length
                  ? SfStatus.good
                  : SfStatus.pending,
            ),
          ),
          const SizedBox(height: SfSpace.x20),
          _permission(
            permission: Permission.locationWhenInUse,
            icon: Icons.my_location_rounded,
            title: 'Vị trí khi đang mở app',
            why: 'Dẫn đường, gửi telemetry và định vị khi bạn gọi cứu hộ.',
            ifDenied: 'Không dẫn đường được và SOS không kèm toạ độ.',
            mandatory: true,
          ),
          _permission(
            permission: Permission.locationAlways,
            icon: Icons.location_searching_rounded,
            title: 'Vị trí khi chạy nền',
            why: 'Điều hành vẫn thấy xe khi bạn chuyển sang ứng dụng khác.',
            ifDenied: 'Vị trí xe đứng yên trên màn điều hành khi bạn thoát app.',
          ),
          _permission(
            permission: Permission.camera,
            icon: Icons.camera_alt_outlined,
            title: 'Camera',
            why:
                'Giám sát buồn ngủ ngay trên máy và chụp ảnh hiện trường điểm ngập.',
            ifDenied: 'Không có cảnh báo buồn ngủ.',
            mandatory: true,
          ),
          _permission(
            permission: Permission.microphone,
            icon: Icons.mic_none_rounded,
            title: 'Micro',
            why: 'Ra lệnh bằng giọng nói để không phải rời tay khỏi vô lăng.',
            ifDenied: 'Chỉ dùng được trợ lý bằng cách gõ chữ.',
          ),
          _permission(
            permission: Permission.notification,
            icon: Icons.notifications_none_rounded,
            title: 'Thông báo',
            why: 'Nhận chuyến mới, cảnh báo ngập và phản hồi SOS.',
            ifDenied: 'Bạn có thể bỏ lỡ chuyến được giao và cảnh báo ngập.',
            mandatory: true,
          ),
          const SizedBox(height: SfSpace.x20),
          SfPrimaryAction(
            label: 'Cho phép các quyền cần thiết',
            icon: Icons.shield_outlined,
            busy: _busy,
            onPressed: _request,
          ),
          const SizedBox(height: SfSpace.x8),
          TextButton(
            onPressed: openAppSettings,
            child: const Text('Mở cài đặt hệ thống'),
          ),
        ],
      ),
    );
  }

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
    return Padding(
      padding: const EdgeInsets.only(bottom: SfSpace.x12),
      child: SfCard(
        emphasis: granted || !mandatory ? null : SfStatus.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: SfTouch.min,
                  height: SfTouch.min,
                  decoration: BoxDecoration(
                    color: granted ? p.goodTint : p.surfaceAlt,
                    borderRadius: SfRadius.controlR,
                  ),
                  child: Icon(
                    icon,
                    color: granted ? SfColors.success : p.textSecondary,
                  ),
                ),
                const SizedBox(width: SfSpace.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SfType.titleCard.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                      if (mandatory)
                        Text(
                          'Bắt buộc',
                          style: SfType.label.copyWith(color: p.textMuted),
                        ),
                    ],
                  ),
                ),
                SfStatusPill(
                  granted ? 'Đã bật' : 'Chưa bật',
                  status: granted ? SfStatus.good : SfStatus.pending,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: SfSpace.x12),
            Text(why, style: SfType.body.copyWith(color: p.textSecondary)),
            if (!granted) ...[
              const SizedBox(height: SfSpace.x8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: SfColors.amber,
                  ),
                  const SizedBox(width: SfSpace.x8),
                  Expanded(
                    child: Text(
                      'Nếu từ chối: $ifDenied',
                      style: SfType.meta.copyWith(color: p.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
