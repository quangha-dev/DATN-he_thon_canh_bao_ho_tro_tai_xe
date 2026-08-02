import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/motion.dart';
import '../design/tokens.dart';

/// Bọc một widget để nó lún nhẹ khi nhấn (0.97), nảy nhẹ khi nhả.
///
/// Khi [onTap] là null, widget chỉ theo dõi con trỏ bằng [Listener] — không
/// tham gia đấu trường cử chỉ, nên không bao giờ cướp cú chạm của widget con
/// (ví dụ khi bọc quanh một FilledButton). Chạm giữa lúc animation đang chạy
/// vẫn ăn — animation không bao giờ chặn tay người dùng.
class SfPressable extends StatefulWidget {
  const SfPressable({required this.child, super.key, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<SfPressable> createState() => _SfPressableState();
}

class _SfPressableState extends State<SfPressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final scaled = AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: SfMotion.of(context, SfMotion.dPress),
      curve: _down
          ? SfMotion.curveOf(context, SfMotion.standard)
          : SfMotion.curveOf(context, SfMotion.emphasis),
      child: widget.child,
    );

    if (widget.onTap == null) {
      return Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: scaled,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap,
      child: scaled,
    );
  }
}

/// Nút chính — cao 52, bo góc 14.
class SfPrimaryAction extends StatelessWidget {
  const SfPrimaryAction({
    required this.label,
    super.key,
    this.icon,
    this.onPressed,
    this.busy = false,
    this.tone,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  /// Màu nền thay thế (ví dụ [SfColors.danger] cho SOS).
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final child = busy
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: SfSpace.x8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    // Không truyền onTap: FilledButton tự xử lý cú chạm, SfPressable chỉ lo
    // hiệu ứng lún.
    return SfPressable(
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tone ?? p.accent,
          foregroundColor: tone == null ? p.onAccent : SfColors.onAccent,
          minimumSize: const Size.fromHeight(SfTouch.primaryHeight),
          textStyle: SfType.titleCard,
          shape: const RoundedRectangleBorder(borderRadius: SfRadius.controlR),
        ),
        child: child,
      ),
    );
  }
}

/// Nút cỡ lớn cho chế độ lái — cao 64, chữ ≥ 18px, vùng chạm 64dp.
class SfDriveAction extends StatelessWidget {
  const SfDriveAction({
    required this.label,
    required this.icon,
    super.key,
    this.onPressed,
    this.tone,
    this.expanded = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? tone;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final bg = tone ?? p.surfaceAlt;
    final ink = tone == null ? p.textPrimary : SfColors.onAccent;
    final button = SfPressable(
      onTap: onPressed,
      child: Container(
        height: SfTouch.driveHeight,
        constraints: const BoxConstraints(minWidth: SfTouch.drive),
        padding: const EdgeInsets.symmetric(horizontal: SfSpace.x20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: SfRadius.controlR,
          border: Border.all(color: tone == null ? p.border : bg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: ink),
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
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Nút xác nhận giữ 2 giây — tránh gửi nhầm khi đang lái.
class SfHoldToConfirm extends StatefulWidget {
  const SfHoldToConfirm({
    required this.label,
    required this.onConfirmed,
    super.key,
    this.icon = Icons.check_rounded,
    this.tone = SfColors.danger,
    this.holdDuration = const Duration(seconds: 2),
    this.hint = 'Giữ 2 giây để xác nhận',
  });

  final String label;
  final VoidCallback onConfirmed;
  final IconData icon;
  final Color tone;
  final Duration holdDuration;
  final String hint;

  @override
  State<SfHoldToConfirm> createState() => _SfHoldToConfirmState();
}

class _SfHoldToConfirmState extends State<SfHoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.heavyImpact();
      widget.onConfirmed();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.selectionClick();
    _controller.forward();
  }

  void _cancel() {
    if (_controller.isAnimating) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _start(),
    onTapUp: (_) => _cancel(),
    onTapCancel: _cancel,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: SfRadius.controlR,
          child: Stack(
            children: [
              Container(
                height: SfTouch.driveHeight,
                width: double.infinity,
                color: widget.tone.withValues(alpha: 0.18),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => FractionallySizedBox(
                  widthFactor: _controller.value,
                  child: Container(
                    height: SfTouch.driveHeight,
                    color: widget.tone,
                  ),
                ),
              ),
              SizedBox(
                height: SfTouch.driveHeight,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: SfColors.onAccent, size: 24),
                    const SizedBox(width: SfSpace.x12),
                    Text(
                      widget.label,
                      style: SfType.titleCard.copyWith(
                        color: SfColors.onAccent,
                        fontSize: SfTouch.driveFontFloor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SfSpace.x8),
        Text(
          widget.hint,
          style: SfType.meta.copyWith(color: context.sf.textSecondary),
        ),
      ],
    ),
  );
}
