import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'sf_card.dart';
import 'sf_scaffold.dart';
import 'sf_status.dart';

export '../design/motion.dart';
export '../design/routes.dart';
export '../design/theme.dart';
export '../design/tokens.dart';
export 'sf_actions.dart';
export 'sf_alert_banner.dart';
export 'sf_card.dart';
export 'sf_gauge.dart';
export 'sf_scaffold.dart';
export 'sf_status.dart';
export 'sf_trip_card.dart';

/// Cửa vào thư viện giao diện SafeFleet.
///
/// Mọi màn dựng từ các widget `Sf*` được export ở trên, không tự vẽ lại.
///
/// Ba lớp bên dưới chỉ là bọc tương thích cho mã cũ — chúng gọi thẳng vào
/// widget `Sf*` tương ứng nên đã mang giao diện mới. Mỗi bước ở phần 8 gỡ dần
/// chúng khỏi một màn; xóa hẳn khi không còn chỗ nào tham chiếu.
/// Chưa gắn `@Deprecated` để `flutter analyze` không nổi cảnh báo trong lúc
/// các màn còn đang chuyển đổi.

/// Bọc tương thích — dùng `SfScreenTitle` hoặc `SfScreenScaffold` cho mã mới.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle({
    required this.title,
    required this.subtitle,
    super.key,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) =>
      SfScreenTitle(title: title, subtitle: subtitle, trailing: trailing);
}

/// Bọc tương thích — dùng `SfStatusPill` với 4 mức `SfStatus` cho mã mới.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.good = true, this.icon});

  final String label;
  final bool good;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SfStatusPill(
    label,
    status: good ? SfStatus.good : SfStatus.danger,
    icon: icon,
    dense: true,
  );
}

/// Bọc tương thích — dùng `SfEmptyState` cho mã mới.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) =>
      SfEmptyState(icon: icon, title: title, message: message);
}

/// Phản hồi lỗi thao tác. KHÔNG dùng cho cảnh báo an toàn — cảnh báo an toàn
/// đi qua `SfAlertBanner` / `SfCriticalAlertOverlay`.
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '$error',
          style: SfType.body.copyWith(color: SfColors.onDanger),
        ),
        backgroundColor: SfColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: SfRadius.controlR),
      ),
    );
}
