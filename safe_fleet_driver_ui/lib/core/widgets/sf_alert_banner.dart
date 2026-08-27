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

  /// Cấp 1 — có dấu hiệu buồn ngủ. Nền vàng cảnh báo, viền trong nhịp đập.
  caution,

  /// Cấp 2 — nguy hiểm. Lớp phủ đỏ tràn màn, không thể bỏ qua.
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
          color: SfColors.warningBg,
          borderRadius: SfRadius.cardR,
          border: Border.all(
            color: SfColors.warning.withValues(
              alpha: reduced ? 0.55 : 0.3 + _pulse.value * 0.55,
            ),
            width: 2,
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
                  color: SfColors.warning,
                  size: 26,
                ),
                const SizedBox(width: SfSpace.x12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: SfType.titleCard.copyWith(
                      color: SfColors.warningInk,
                      fontSize: SfTouch.driveFontFloor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.onDismiss != null)
                  IconButton(
                    onPressed: widget.onDismiss,
                    iconSize: 20,
                    color: SfColors.warningInk,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: SfSpace.x8),
            Text(
              widget.message,
              style: SfType.body.copyWith(
                color: SfColors.warningInk,
                fontSize: SfTouch.driveFontFloor,
              ),
            ),
            if (widget.source != null) ...[
              const SizedBox(height: SfSpace.x8),
              _SourceLabel(widget.source!, ink: SfColors.warning),
            ],
            if (widget.primaryLabel != null) ...[
              const SizedBox(height: SfSpace.x16),
              _AlertButton(
                label: widget.primaryLabel!,
                icon: Icons.local_parking_rounded,
                background: SfColors.warningInk,
                ink: SfColors.warningBg,
                onPressed: widget.onPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---- Cấp 2 ----
  Widget _buildCritical(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: SfColors.danger,
      borderRadius: SfRadius.cardR,
      border: Border.all(
        color: SfColors.onDanger.withValues(alpha: 0.85),
        width: 3,
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
                style: SfType.titleSub.copyWith(color: SfColors.onDanger),
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
    borderRadius: SfRadius.controlLgR,
    child: InkWell(
      onTap: onPressed,
      borderRadius: SfRadius.controlLgR,
      child: SizedBox(
        height: SfTouch.driveHeight,
        width: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ink, size: 24),
            const SizedBox(width: SfSpace.x12),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: SfType.titleCard.copyWith(
                  color: ink,
                  fontSize: SfTouch.driveFontFloor,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Lớp phủ cảnh báo buồn ngủ — tràn màn hình, cắt vào trong 120ms tuyến tính.
///
/// Theo bản thiết kế (màn Chế độ lái, state `drowsy`): nền đỏ sẫm phủ kín,
/// icon `bedtime` 62px trong vòng loang 118px, tiêu đề 34px, hai nút thoát và
/// chú thích cho biết đã rung + báo điều hành.
///
/// Không đi qua [SfMotion.of]: cảnh báo an toàn không bị tắt bởi cài đặt
/// "giảm chuyển động". Chặn mọi tương tác phía dưới; chỉ thoát bằng 1 trong 2
/// nút.
class SfCriticalAlertOverlay extends StatelessWidget {
  const SfCriticalAlertOverlay({
    required this.title,
    required this.message,
    super.key,
    this.source,
    this.actionLabel,
    this.onAction,
    this.dismissLabel,
    this.onDismiss,
    this.footnote = 'Rung mạnh + chuông. Điều hành đã được thông báo.',
    this.icon = Icons.bedtime_rounded,
  });

  final String title;
  final String message;
  final String? source;

  /// Nút trắng chính — "Tìm chỗ nghỉ gần nhất".
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Nút viền phụ — "Tôi vẫn tỉnh — tắt cảnh báo".
  final String? dismissLabel;
  final VoidCallback? onDismiss;

  final String footnote;
  final IconData icon;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: SfMotion.dAlert,
    curve: Curves.linear,
    builder: (context, value, child) => Opacity(opacity: value, child: child),
    child: Material(
      color: SfColors.drowsyScrim,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SfSpace.x24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _PulsingIcon(icon: icon)),
              const SizedBox(height: SfSpace.x32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: SfType.displayDrive.copyWith(color: SfColors.onDanger),
              ),
              const SizedBox(height: SfSpace.x14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: SfType.body.copyWith(
                  color: SfColors.onDanger.withValues(alpha: 0.92),
                  fontSize: SfTouch.driveFontFloor,
                ),
              ),
              if (source != null) ...[
                const SizedBox(height: SfSpace.x12),
                Center(
                  child: _SourceLabel(source!, ink: SfColors.onDanger),
                ),
              ],
              const SizedBox(height: SfSpace.x32),
              _AlertButton(
                label: actionLabel ?? 'Tìm chỗ nghỉ gần nhất',
                icon: Icons.local_parking_rounded,
                background: SfColors.onDanger,
                ink: SfColors.dangerStrong,
                onPressed: onAction,
              ),
              if (dismissLabel != null) ...[
                const SizedBox(height: SfSpace.x12),
                _OutlinedAlertButton(
                  label: dismissLabel!,
                  onPressed: onDismiss,
                ),
              ],
              const SizedBox(height: SfSpace.x20),
              Text(
                footnote,
                textAlign: TextAlign.center,
                style: SfType.caption.copyWith(
                  color: SfColors.onDanger.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OutlinedAlertButton extends StatelessWidget {
  const _OutlinedAlertButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: SfRadius.controlLgR,
    child: InkWell(
      onTap: onPressed,
      borderRadius: SfRadius.controlLgR,
      child: Container(
        height: SfTouch.primaryHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: SfRadius.controlLgR,
          border: Border.all(
            color: SfColors.onDanger.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: SfType.titleCardSm.copyWith(
            color: SfColors.onDanger,
            fontSize: SfTouch.driveFontFloor,
          ),
        ),
      ),
    ),
  );
}

/// Icon 62px trong vòng 118px đập nhịp 1.1s.
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.icon});

  final IconData icon;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 118,
      height: 118,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SfColors.onDanger.withValues(alpha: 0.12),
        border: Border.all(
          color: SfColors.onDanger.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Icon(widget.icon, size: 62, color: SfColors.onDanger),
    );
    // Cảnh báo an toàn luôn chạy, kể cả khi hệ thống bật giảm chuyển động.
    return ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1.06).animate(_controller),
      child: circle,
    );
  }
}
