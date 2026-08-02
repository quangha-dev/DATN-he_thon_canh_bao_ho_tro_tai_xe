import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/tokens.dart';
import 'sf_status.dart';

/// Thẻ chuẩn: surface + viền 1px + bo góc 20, không đổ bóng.
///
/// Biến thể [emphasis]: viền theo màu trạng thái + dải màu 3px trên đỉnh.
class SfCard extends StatelessWidget {
  const SfCard({
    required this.child,
    super.key,
    this.emphasis,
    this.padding = SfSpace.card,
    this.onTap,
    this.background,
  });

  final Widget child;
  final SfStatus? emphasis;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final accent = emphasis?.inkOf(p);
    final content = Padding(padding: padding, child: child);

    return Material(
      color: background ?? p.surface,
      borderRadius: SfRadius.cardR,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: SfRadius.cardR,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: SfRadius.cardR,
            border: Border.all(color: accent ?? p.border),
          ),
          child: accent == null
              ? content
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 3, color: accent),
                    content,
                  ],
                ),
        ),
      ),
    );
  }
}

/// Nhãn nhỏ phía trên, số lớn phía dưới.
///
/// Biến thể [drive] dùng cỡ 44 cho chế độ lái.
class SfMetric extends StatelessWidget {
  const SfMetric({
    required this.label,
    required this.value,
    super.key,
    this.unit,
    this.drive = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? unit;
  final bool drive;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final valueStyle = (drive ? SfType.displayDrive : SfType.mono).copyWith(
      color: valueColor ?? p.textPrimary,
      fontSize: drive ? null : 20,
      fontWeight: FontWeight.w700,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: SfType.label.copyWith(
            color: p.textSecondary,
            fontSize: drive ? SfTouch.driveFontFloor : null,
          ),
        ),
        const SizedBox(height: SfSpace.x4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: valueStyle),
            if (unit != null) ...[
              const SizedBox(width: SfSpace.x4),
              Text(
                unit!,
                style:
                    (drive
                            ? SfType.titleCard.copyWith(
                                fontSize: SfTouch.driveFontFloor,
                              )
                            : SfType.meta)
                        .copyWith(color: p.textSecondary),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Trạng thái rỗng: nói rõ chuyện gì đang xảy ra và làm gì tiếp.
class SfEmptyState extends StatelessWidget {
  const SfEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SfSpace.x32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: p.textMuted),
            const SizedBox(height: SfSpace.x16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SfType.titleCard.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: SfSpace.x8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: SfType.body.copyWith(color: p.textSecondary),
            ),
            if (action != null) ...[
              const SizedBox(height: SfSpace.x20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Khối xám nhấp nháy nhẹ khi đang tải. Không dùng spinner giữa màn.
class SfSkeleton extends StatefulWidget {
  const SfSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = SfRadius.control,
  });

  /// Vài dòng skeleton cho một thẻ.
  static Widget card({int lines = 3}) => _SkeletonCard(lines: lines);

  final double height;
  final double? width;
  final double radius;

  @override
  State<SfSkeleton> createState() => _SfSkeletonState();
}

class _SfSkeletonState extends State<SfSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SfMotion.dSkeleton,
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
    final p = context.sf;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: reduced ? 0.6 : 0.45 + _controller.value * 0.35,
        child: Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) => SfCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SfSkeleton(height: 20, width: 140),
        const SizedBox(height: SfSpace.x12),
        for (var i = 0; i < lines; i++) ...[
          SfSkeleton(width: i.isEven ? double.infinity : 200),
          if (i != lines - 1) const SizedBox(height: SfSpace.x8),
        ],
      ],
    ),
  );
}
