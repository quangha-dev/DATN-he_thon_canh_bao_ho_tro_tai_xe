import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Bốn mức trạng thái dùng chung cho toàn app.
///
/// Mọi trạng thái phải nhận ra được bằng **hình dạng + nhãn chữ**, không chỉ
/// bằng màu — tài xế lớn tuổi, mù màu, đeo kính râm, hoặc đang dưới nắng gắt.
enum SfStatus { good, pending, warning, danger }

extension SfStatusVisual on SfStatus {
  IconData get icon => switch (this) {
    SfStatus.good => Icons.check_circle_rounded,
    SfStatus.pending => Icons.schedule_rounded,
    SfStatus.warning => Icons.warning_amber_rounded,
    SfStatus.danger => Icons.error_rounded,
  };

  Color get ink => switch (this) {
    SfStatus.good => SfColors.success,
    SfStatus.pending => SfColors.navy500,
    SfStatus.warning => SfColors.amber,
    SfStatus.danger => SfColors.danger,
  };

  /// Màu chữ/icon đủ tương phản trên nền tối.
  Color get inkOnDark => switch (this) {
    SfStatus.good => SfColors.mint,
    SfStatus.pending => SfColors.darkTextSecondary,
    SfStatus.warning => SfColors.amber,
    SfStatus.danger => SfColors.dangerHot,
  };

  Color tint(SfPalette p) => switch (this) {
    SfStatus.good => p.goodTint,
    SfStatus.pending => p.isDark ? p.surfaceAlt : SfColors.navyTint,
    SfStatus.warning => p.warnTint,
    SfStatus.danger => p.dangerTint,
  };

  Color inkOf(SfPalette p) => p.isDark ? inkOnDark : ink;
}

/// Pill trạng thái — luôn có icon + chữ, không bao giờ chỉ có màu.
class SfStatusPill extends StatelessWidget {
  const SfStatusPill(
    this.label, {
    super.key,
    this.status = SfStatus.good,
    this.icon,
    this.dense = false,
  });

  final String label;
  final SfStatus status;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final ink = status.inkOf(p);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? SfSpace.x8 : SfSpace.x12,
        vertical: SfSpace.x4 + (dense ? 0 : 2),
      ),
      decoration: BoxDecoration(
        color: status.tint(p),
        borderRadius: SfRadius.pillR,
        border: Border.all(color: ink.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? status.icon, size: 15, color: ink),
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

/// Nhãn nhóm / kicker — VIẾT HOA, letter-spacing rộng.
class SfSectionLabel extends StatelessWidget {
  const SfSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          text.toUpperCase(),
          style: SfType.label.copyWith(color: context.sf.textSecondary),
        ),
      ),
      ?trailing,
    ],
  );
}

/// Tình trạng kết nối. Ngoại tuyến là trạng thái bình thường, không phải lỗi —
/// nên nó dùng chung ngôn ngữ với mọi trạng thái khác, không tô đỏ.
class SfConnectionChip extends StatelessWidget {
  const SfConnectionChip({
    required this.online,
    super.key,
    this.pendingCount = 0,
  });

  final bool online;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final (label, status, icon) = switch ((online, pendingCount)) {
      (true, 0) => ('Trực tuyến', SfStatus.good, Icons.cloud_done_rounded),
      (true, _) => (
        '$pendingCount chờ đồng bộ',
        SfStatus.pending,
        Icons.cloud_sync_rounded,
      ),
      (false, 0) => ('Ngoại tuyến', SfStatus.pending, Icons.cloud_off_rounded),
      (false, _) => (
        'Ngoại tuyến · $pendingCount chờ',
        SfStatus.pending,
        Icons.cloud_off_rounded,
      ),
    };
    return SfStatusPill(label, status: status, icon: icon, dense: true);
  }
}
