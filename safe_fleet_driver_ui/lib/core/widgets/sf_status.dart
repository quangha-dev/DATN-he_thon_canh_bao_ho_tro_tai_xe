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
    SfStatus.good => SfColors.green700,
    SfStatus.pending => SfColors.info,
    SfStatus.warning => SfColors.warning,
    SfStatus.danger => SfColors.danger,
  };

  /// Màu chữ/icon đủ tương phản trên nền tối.
  Color get inkOnDark => switch (this) {
    SfStatus.good => SfColors.green400,
    SfStatus.pending => SfColors.infoLight,
    SfStatus.warning => SfColors.amber,
    SfStatus.danger => SfColors.dangerSoft,
  };

  Color tint(SfPalette p) => switch (this) {
    SfStatus.good => p.goodTint,
    SfStatus.pending => p.isDark ? p.surfaceAlt : SfColors.infoBg,
    SfStatus.warning => p.warnTint,
    SfStatus.danger => p.dangerTint,
  };

  /// Viền của thẻ/chip mang trạng thái này.
  Color borderOf(SfPalette p) => p.isDark
      ? inkOnDark.withValues(alpha: 0.34)
      : switch (this) {
          SfStatus.good => SfColors.borderChecked,
          SfStatus.pending => SfColors.borderStrong,
          SfStatus.warning => SfColors.warningBorder,
          SfStatus.danger => SfColors.dangerBorder,
        };

  Color inkOf(SfPalette p) => p.isDark ? inkOnDark : ink;
}

/// Chip trạng thái — VIẾT HOA, 10.5/600, letter-spacing .06em.
///
/// Luôn có nhãn chữ; icon là tuỳ chọn vì nhiều chip trong thiết kế chỉ có chữ
/// ("ĐANG THỰC HIỆN", "CÒN HẠN"). Trạng thái không bao giờ chỉ báo bằng màu.
class SfStatusPill extends StatelessWidget {
  const SfStatusPill(
    this.label, {
    super.key,
    this.status = SfStatus.good,
    this.icon,
    this.dense = false,
    this.showIcon = false,
    this.ink,
    this.background,
    this.borderColor,
  });

  /// Chip đặt trên nền xanh đậm (thẻ hero): nền trắng 18%, chữ trắng.
  const SfStatusPill.onHero(
    this.label, {
    super.key,
    this.icon,
    this.dense = true,
    this.showIcon = false,
  }) : status = SfStatus.good,
       ink = SfColors.onAccent,
       background = const Color(0x2EFFFFFF),
       borderColor = Colors.transparent;

  /// Chip nhấn màu hổ phách trên nền xanh — "RỦI RO CAO".
  const SfStatusPill.amber(
    this.label, {
    super.key,
    this.icon,
    this.dense = true,
    this.showIcon = false,
  }) : status = SfStatus.warning,
       ink = SfColors.amberInk,
       background = SfColors.amber,
       borderColor = Colors.transparent;

  final String label;
  final SfStatus status;
  final IconData? icon;
  final bool dense;

  /// Hiện icon trạng thái mặc định khi không truyền [icon].
  final bool showIcon;

  final Color? ink;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final fg = ink ?? status.inkOf(p);
    final glyph = icon ?? (showIcon ? status.icon : null);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? SfSpace.x8 : SfSpace.x10,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background ?? status.tint(p),
        borderRadius: SfRadius.pillR,
        border: Border.all(color: borderColor ?? status.borderOf(p)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            Icon(glyph, size: 13, color: fg),
            const SizedBox(width: SfSpace.x4),
          ],
          Text(
            label.toUpperCase(),
            style: SfType.chip.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Chip lọc dạng pill — "Tất cả / Ngập nước / Điểm đen / Trạm nghỉ".
class SfFilterChip extends StatelessWidget {
  const SfFilterChip({
    required this.label,
    required this.selected,
    super.key,
    this.onTap,
    this.onDark = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Đặt trên nền tối / trên bản đồ.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final bg = selected
        ? SfColors.green700
        : (onDark ? SfColors.darkSurface : p.surface);
    final fg = selected
        ? SfColors.onAccent
        : (onDark ? SfColors.darkTextSecondary : p.textSecondary);
    return Material(
      color: bg,
      borderRadius: SfRadius.pillR,
      child: InkWell(
        onTap: onTap,
        borderRadius: SfRadius.pillR,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: SfSpace.x14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: SfRadius.pillR,
            border: Border.all(
              color: selected
                  ? SfColors.green700
                  : (onDark ? SfColors.darkBorder : p.border),
            ),
          ),
          child: Text(
            label,
            style: SfType.meta.copyWith(
              color: fg,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Chấm trạng thái nhấp nháy 2s (`sfblink`) — dùng cạnh "Đang lái · xe …".
class SfPulseDot extends StatefulWidget {
  const SfPulseDot({
    super.key,
    this.size = 8,
    this.color = SfColors.green400,
  });

  final double size;
  final Color color;

  @override
  State<SfPulseDot> createState() => _SfPulseDotState();
}

class _SfPulseDotState extends State<SfPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (MediaQuery.disableAnimationsOf(context)) return dot;
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(_controller),
      child: dot,
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
