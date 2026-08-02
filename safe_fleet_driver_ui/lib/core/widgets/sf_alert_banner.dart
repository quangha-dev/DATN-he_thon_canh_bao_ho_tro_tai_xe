import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/tokens.dart';

/// Ba cấp cảnh báo an toàn, leo thang.
///
/// Cảnh báo an toàn không "đẹp". Nó xuất hiện tức thì, thô, không easing mềm —
/// như một cái phanh khẩn cấp. Đây là ngôn ngữ thị giác RIÊNG, không dùng chung
/// với bất kỳ thành phần nào khác, và không bao giờ là SnackBar.
enum SfAlertLevel {
  /// Cấp 0 — bình thường. Thẻ surface, không hiệu ứng.
  calm,

  /// Cấp 1 — có dấu hiệu buồn ngủ. Nền amber, viền trong nhịp đập.
  caution,

  /// Cấp 2 — nguy hiểm. Nền đỏ tràn, không thể bỏ qua.
  critical,
}

/// Banner cảnh báo an toàn.
///
/// [source] là nhãn nhỏ cho biết engine nào đang chạy (STGT TFLite / ML Kit
/// fallback) — tài xế và điều hành viên đều cần biết, không được ẩn đi.
class SfAlertBanner extends StatefulWidget {
  const SfAlertBanner({
    required this.level,
    required this.title,
    required this.message,
    super.key,
    this.source,
    this.primaryLabel,
    this.onPrimary,
    this.onDismiss,
  });

  final SfAlertLevel level;
  final String title;
  final String message;
  final String? source;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// Chỉ có tác dụng ở cấp 0 và cấp 1. Cấp 2 không có nút bỏ qua.
  final VoidCallback? onDismiss;

  @override
  State<SfAlertBanner> createState() => _SfAlertBannerState();
}

class _SfAlertBannerState extends State<SfAlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(SfAlertBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) _syncPulse();
  }

  void _syncPulse() {
    if (widget.level == SfAlertLevel.caution) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (widget.level) {
    SfAlertLevel.calm => _buildCalm(context),
    SfAlertLevel.caution => _buildCaution(context),
    SfAlertLevel.critical => _buildCritical(context),
  };

  // ---- Cấp 0 ----
  Widget _buildCalm(BuildContext context) {
    final p = context.sf;
    return Container(
      padding: const EdgeInsets.all(SfSpace.x16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: SfRadius.cardR,
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: p.accent, size: 24),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: SfType.titleCard.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  widget.message,
                  style: SfType.meta.copyWith(color: p.textSecondary),
                ),
                if (widget.source != null) ...[
                  const SizedBox(height: SfSpace.x8),
                  _SourceLabel(widget.source!, ink: p.textMuted),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Cấp 1 ----
  Widget _buildCaution(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          color: SfColors.amber,
          borderRadius: SfRadius.cardR,
          border: Border.all(
            color: SfColors.amberInk.withValues(
              alpha: reduced ? 0.35 : 0.15 + _pulse.value * 0.45,
            ),
            width: 3,
          ),
        ),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.all(SfSpace.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: SfColors.amberInk,
                  size: 26,
                ),
                const SizedBox(width: SfSpace.x12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: SfType.titleCard.copyWith(
                      color: SfColors.amberInk,
                      fontSize: SfTouch.driveFontFloor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.onDismiss != null)
                  IconButton(
                    onPressed: widget.onDismiss,
                    iconSize: 20,
                    color: SfColors.amberInk,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: SfSpace.x8),
            Text(
              widget.message,
              style: SfType.body.copyWith(
                color: SfColors.amberInk,
                fontSize: SfTouch.driveFontFloor,
              ),
            ),
            if (widget.source != null) ...[
              const SizedBox(height: SfSpace.x8),
              _SourceLabel(widget.source!, ink: SfColors.amberInk),
            ],
            if (widget.primaryLabel != null) ...[
              const SizedBox(height: SfSpace.x16),
              _AlertButton(
                label: widget.primaryLabel!,
                icon: Icons.local_parking_rounded,
                background: SfColors.amberInk,
                ink: SfColors.amber,
                onPressed: widget.onPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---- Cấp 2 ----
  Widget _buildCritical(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        radius: 1.1,
        colors: [SfColors.dangerHot, SfColors.danger],
      ),
    ),
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: SfColors.onDanger.withValues(alpha: 0.85),
          width: 6,
        ),
      ),
      padding: const EdgeInsets.all(SfSpace.x20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.report_rounded,
                color: SfColors.onDanger,
                size: 34,
              ),
              const SizedBox(width: SfSpace.x12),
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  style: SfType.titleScreen.copyWith(
                    color: SfColors.onDanger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x12),
          Text(
            widget.message,
            style: SfType.body.copyWith(
              color: SfColors.onDanger,
              fontSize: SfTouch.driveFontFloor,
            ),
          ),
          if (widget.source != null) ...[
            const SizedBox(height: SfSpace.x12),
            _SourceLabel(widget.source!, ink: SfColors.onDanger),
          ],
          const SizedBox(height: SfSpace.x20),
          // Không có nút "Bỏ qua". Chỉ một lối ra duy nhất.
          _AlertButton(
            label: widget.primaryLabel ?? 'Tôi sẽ nghỉ ngay',
            icon: Icons.pan_tool_rounded,
            background: SfColors.onDanger,
            ink: SfColors.danger,
            onPressed: widget.onPrimary,
          ),
        ],
      ),
    ),
  );
}

class _SourceLabel extends StatelessWidget {
  const _SourceLabel(this.source, {required this.ink});

  final String source;
  final Color ink;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.memory_rounded, size: 13, color: ink),
      const SizedBox(width: SfSpace.x4),
      Text(
        source.toUpperCase(),
        style: SfType.label.copyWith(color: ink),
      ),
    ],
  );
}

class _AlertButton extends StatelessWidget {
  const _AlertButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.ink,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color ink;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    borderRadius: SfRadius.controlR,
    child: InkWell(
      onTap: onPressed,
      borderRadius: SfRadius.controlR,
      child: SizedBox(
        height: SfTouch.driveHeight,
        width: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ink, size: 24),
            const SizedBox(width: SfSpace.x12),
            Text(
              label,
              style: SfType.titleCard.copyWith(
                color: ink,
                fontSize: SfTouch.driveFontFloor,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Lớp phủ cảnh báo cấp 2 — tràn màn hình, cắt vào trong 120ms tuyến tính.
///
/// Không đi qua [SfMotion.of]: cảnh báo an toàn không bị tắt bởi cài đặt
/// "giảm chuyển động".
class SfCriticalAlertOverlay extends StatelessWidget {
  const SfCriticalAlertOverlay({
    required this.title,
    required this.message,
    super.key,
    this.source,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? source;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: SfMotion.dAlert,
    curve: Curves.linear,
    builder: (context, value, child) =>
        Opacity(opacity: value, child: child),
    child: Material(
      color: SfColors.dangerHot,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SfSpace.x16),
            child: SfAlertBanner(
              level: SfAlertLevel.critical,
              title: title,
              message: message,
              source: source,
              primaryLabel: actionLabel,
              onPrimary: onAction,
            ),
          ),
        ),
      ),
    ),
  );
}
