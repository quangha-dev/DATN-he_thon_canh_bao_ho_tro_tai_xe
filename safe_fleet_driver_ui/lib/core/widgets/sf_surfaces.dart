import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/tokens.dart';
import 'sf_status.dart';

/// Thẻ hero gradient xanh — thẻ chuyến đang chạy, thẻ điểm tháng.
class SfHeroCard extends StatelessWidget {
  const SfHeroCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(SfSpace.x18),
    this.gradient = SfGradients.heroTrip,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: SfRadius.heroR,
      boxShadow: SfShadow.hero,
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: SfRadius.heroR,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: SfRadius.heroR,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: SfRadius.heroR,
          child: Padding(padding: padding, child: child),
        ),
      ),
    ),
  );
}

/// Header gradient của màn con: nút back, tiêu đề, phụ đề, hành động phải.
///
/// Dùng làm `SliverAppBar`-thay-thế: đặt trên cùng của [Column] trong màn con.
class SfGradientHeader extends StatelessWidget {
  const SfGradientHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.showBack = true,
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(
      SfSpace.x16,
      SfSpace.x12,
      SfSpace.x16,
      SfSpace.x18,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool showBack;

  /// Nội dung thêm dưới hàng tiêu đề — ví dụ 3 ô số của Chi tiết chuyến.
  final Widget? bottom;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: SfGradients.header),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showBack) ...[
                  SfIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    onHero: true,
                    tooltip: 'Quay lại',
                  ),
                  const SizedBox(width: SfSpace.x12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SfType.titleSub.copyWith(
                          color: SfColors.onAccent,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: SfType.meta.copyWith(
                            color: SfColors.green300,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: SfSpace.x12),
                  trailing!,
                ],
              ],
            ),
            if (bottom != null) ...[
              const SizedBox(height: SfSpace.x18),
              bottom!,
            ],
          ],
        ),
      ),
    ),
  );
}

/// Nút icon vuông bo góc — 42px trên header màn tab, 46px trên bản đồ.
class SfIconButton extends StatelessWidget {
  const SfIconButton({
    required this.icon,
    super.key,
    this.onTap,
    this.size = SfTouch.iconBtn,
    this.badge,
    this.onHero = false,
    this.onDark = false,
    this.tooltip,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  /// Số hiển thị trên huy hiệu đỏ góc trên phải.
  final int? badge;

  /// Đặt trên nền gradient xanh — nền trắng 16%, icon trắng.
  final bool onHero;

  /// Đặt trên nền tối.
  final bool onDark;

  final String? tooltip;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final bg =
        background ??
        (onHero
            ? SfColors.onAccent.withValues(alpha: 0.16)
            : onDark
            ? SfColors.darkSurface
            : p.surface);
    final fg =
        foreground ??
        (onHero
            ? SfColors.onAccent
            : onDark
            ? SfColors.darkTextSecondary
            : SfColors.green700);
    final radius = BorderRadius.circular(SfRadius.iconBtn);

    Widget button = Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: onHero
                  ? Colors.transparent
                  : (onDark ? SfColors.darkBorder : p.border),
            ),
          ),
          child: Icon(icon, size: size * 0.48, color: fg),
        ),
      ),
    );

    if (badge != null && badge! > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SfColors.danger,
                borderRadius: SfRadius.pillR,
                border: Border.all(color: onDark ? p.bg : SfColors.surface),
              ),
              child: Text(
                badge! > 99 ? '99+' : '$badge',
                style: SfType.chip.copyWith(
                  color: SfColors.onAccent,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return tooltip == null
        ? button
        : Tooltip(message: tooltip!, child: button);
  }
}

/// Thanh tiến độ bo tròn, tuỳ chọn vạch mốc và gradient.
class SfProgressBar extends StatelessWidget {
  const SfProgressBar({
    required this.value,
    super.key,
    this.height = 8,
    this.color,
    this.gradient,
    this.trackColor,
    this.ticks = const <double>[],
    this.tickColor,
  });

  /// 0..1
  final double value;
  final double height;
  final Color? color;
  final Gradient? gradient;
  final Color? trackColor;

  /// Vị trí vạch mốc, 0..1.
  final List<double> ticks;
  final Color? tickColor;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final ratio = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color:
                    trackColor ??
                    (p.isDark ? p.surfaceAlt : SfColors.divider),
                borderRadius: SfRadius.pillR,
              ),
            ),
            FractionallySizedBox(
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: gradient == null ? (color ?? p.accent) : null,
                  gradient: gradient,
                  borderRadius: SfRadius.pillR,
                ),
              ),
            ),
            for (final tick in ticks)
              if (tick > 0 && tick < 1)
                Positioned(
                  left: constraints.maxWidth * tick - 1,
                  child: Container(
                    width: 2,
                    height: height,
                    color:
                        tickColor ??
                        (p.isDark ? p.bg : SfColors.surface),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Ô icon bo góc — 40px nền nhạt, dùng ở thao tác nhanh và dòng danh sách.
class SfIconTile extends StatelessWidget {
  const SfIconTile({
    required this.icon,
    super.key,
    this.size = 40,
    this.background,
    this.foreground,
    this.radius = SfRadius.iconBtn,
  });

  final IconData icon;
  final double size;
  final Color? background;
  final Color? foreground;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? (p.isDark ? p.surfaceAlt : SfColors.green100),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: foreground ?? (p.isDark ? p.accent : SfColors.green700),
      ),
    );
  }
}

/// Thẻ thao tác nhanh trong grid 2 cột: icon 40px, tiêu đề, phụ đề.
class SfQuickAction extends StatelessWidget {
  const SfQuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
    this.onTap,
    this.iconBackground,
    this.iconForeground,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconBackground;
  final Color? iconForeground;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Material(
      color: p.surface,
      borderRadius: SfRadius.cardR,
      child: InkWell(
        onTap: onTap,
        borderRadius: SfRadius.cardR,
        child: Container(
          padding: const EdgeInsets.all(SfSpace.x14),
          decoration: BoxDecoration(
            borderRadius: SfRadius.cardR,
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SfIconTile(
                icon: icon,
                background: iconBackground,
                foreground: iconForeground,
              ),
              const SizedBox(height: SfSpace.x12),
              Text(
                title,
                style: SfType.titleRow.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: SfType.caption.copyWith(color: p.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dòng danh sách cao ≥56px: icon, tiêu đề, phụ đề, phần đuôi.
class SfListRow extends StatelessWidget {
  const SfListRow({
    required this.title,
    super.key,
    this.icon,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.subtitleColor,
    this.showChevron = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: SfSpace.x14,
      vertical: SfSpace.x12,
    ),
  });

  final String title;
  final IconData? icon;
  final Widget? leading;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? subtitleColor;
  final bool showChevron;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: SfSpace.x12),
          ] else if (icon != null) ...[
            SfIconTile(icon: icon!),
            const SizedBox(width: SfSpace.x12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: SfType.titleRow.copyWith(
                    color: titleColor ?? p.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: SfType.caption.copyWith(
                      color: subtitleColor ?? p.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: SfSpace.x12),
            trailing!,
          ],
          if (showChevron) ...[
            const SizedBox(width: SfSpace.x8),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: p.textMuted,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SfTouch.row),
        child: row,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SfTouch.row),
          child: row,
        ),
      ),
    );
  }
}

/// Khối thông tin nền nhạt có icon — lời khuyên, nhắc ngoại tuyến, gợi ý.
class SfInfoBox extends StatelessWidget {
  const SfInfoBox({
    required this.text,
    super.key,
    this.icon,
    this.title,
    this.status,
    this.background,
    this.foreground,
    this.borderColor,
    this.trailing,
  });

  final String text;
  final IconData? icon;
  final String? title;

  /// Khi đặt, nền/viền/chữ lấy theo mức trạng thái.
  final SfStatus? status;

  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final ink = foreground ?? status?.inkOf(p) ?? p.textSecondary;
    final bg = background ?? status?.tint(p) ?? (p.isDark ? p.surfaceAlt : SfColors.green050);
    final line = borderColor ?? status?.borderOf(p) ?? Colors.transparent;

    return Container(
      padding: const EdgeInsets.all(SfSpace.x12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: SfRadius.cardSmR,
        border: Border.all(color: line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: ink),
            const SizedBox(width: SfSpace.x10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: SfType.titleRow.copyWith(color: ink),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  text,
                  style: SfType.caption.copyWith(
                    color: title == null ? ink : ink.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: SfSpace.x12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Một ô số: giá trị lớn trên, nhãn nhỏ dưới. Dùng trong grid KPI.
class SfStatCell extends StatelessWidget {
  const SfStatCell({
    required this.value,
    required this.label,
    super.key,
    this.valueColor,
    this.labelColor,
    this.delta,
    this.deltaColor,
    this.align = CrossAxisAlignment.start,
    this.valueStyle,
  });

  final String value;
  final String label;
  final Color? valueColor;
  final Color? labelColor;

  /// Ví dụ "▲8", "▼3", "—".
  final String? delta;
  final Color? deltaColor;
  final CrossAxisAlignment align;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: (valueStyle ?? SfType.stat).copyWith(
                color: valueColor ?? p.textPrimary,
              ),
            ),
            if (delta != null) ...[
              const SizedBox(width: SfSpace.x4),
              Text(
                delta!,
                style: SfType.caption.copyWith(
                  color: deltaColor ?? p.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: SfType.caption.copyWith(color: labelColor ?? p.textMuted),
        ),
      ],
    );
  }
}

/// Một mốc trên timeline lộ trình / nhật ký ngày.
class SfTimelineEntry {
  const SfTimelineEntry({
    required this.title,
    this.time,
    this.subtitle,
    this.color,
    this.icon,
    this.isSquare = false,
  });

  final String title;
  final String? time;
  final String? subtitle;
  final Color? color;
  final IconData? icon;

  /// Mốc cuối vẽ ô vuông thay vì chấm tròn.
  final bool isSquare;
}

/// Timeline dọc: chấm + đường nối + nội dung.
class SfTimeline extends StatelessWidget {
  const SfTimeline({
    required this.entries,
    super.key,
    this.onHero = false,
  });

  final List<SfTimelineEntry> entries;

  /// Đặt trên nền gradient xanh (thẻ hero) — đổi màu chữ và đường nối.
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final titleInk = onHero ? SfColors.onAccent : p.textPrimary;
    final metaInk = onHero
        ? SfColors.green300
        : p.textMuted;
    final lineInk = onHero
        ? SfColors.onAccent.withValues(alpha: 0.34)
        : (p.isDark ? p.border : SfColors.dividerStrong);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    _Marker(
                      entry: entries[i],
                      onHero: onHero,
                      fallback: onHero ? SfColors.onAccent : p.accent,
                    ),
                    if (i != entries.length - 1)
                      Expanded(
                        child: Container(width: 2, color: lineInk),
                      ),
                  ],
                ),
                const SizedBox(width: SfSpace.x12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == entries.length - 1 ? 0 : SfSpace.x18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entries[i].title,
                          style: SfType.titleRow.copyWith(color: titleInk),
                        ),
                        if (entries[i].time != null ||
                            entries[i].subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            [
                              ?entries[i].time,
                              ?entries[i].subtitle,
                            ].join(' · '),
                            style: SfType.caption.copyWith(color: metaInk),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({
    required this.entry,
    required this.onHero,
    required this.fallback,
  });

  final SfTimelineEntry entry;
  final bool onHero;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    final ink = entry.color ?? fallback;
    if (entry.icon != null) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
        child: Icon(entry.icon, size: 13, color: SfColors.onAccent),
      );
    }
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: entry.isSquare ? Colors.transparent : ink,
        border: Border.all(color: ink, width: 3),
        borderRadius: entry.isSquare
            ? BorderRadius.circular(3)
            : BorderRadius.circular(999),
      ),
    );
  }
}

/// Vòng loang `sfpulse` — quanh chấm vị trí, nút SOS, icon cảnh báo.
class SfPulseRing extends StatefulWidget {
  const SfPulseRing({
    required this.child,
    super.key,
    this.color = SfColors.green400,
    this.duration = const Duration(milliseconds: 2600),
    this.maxScale = 1.8,
  });

  final Widget child;
  final Color color;
  final Duration duration;
  final double maxScale;

  @override
  State<SfPulseRing> createState() => _SfPulseRingState();
}

class _SfPulseRingState extends State<SfPulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    // Vòng loang vẽ phía sau, kích thước bám đúng child nhờ Stack không
    // ràng buộc: child quyết định kích thước, Positioned.fill phủ theo.
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.scale(
              scale: 1 + (widget.maxScale - 1) * _controller.value,
              child: Opacity(
                opacity: (1 - _controller.value) * 0.55,
                child: child,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Sóng âm `sfwave` — các vạch cao thấp lệch pha 0.1s.
class SfWaveform extends StatefulWidget {
  const SfWaveform({
    super.key,
    this.bars = 7,
    this.color = SfColors.green400,
    this.height = 26,
    this.barWidth = 4,
    this.gap = 5,
    this.active = true,
  });

  final int bars;
  final Color color;
  final double height;
  final double barWidth;
  final double gap;
  final bool active;

  @override
  State<SfWaveform> createState() => _SfWaveformState();
}

class _SfWaveformState extends State<SfWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(SfWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.bars; i++) ...[
              if (i > 0) SizedBox(width: widget.gap),
              _bar(i, reduced),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(int index, bool reduced) {
    // Lệch pha 0.1s giữa các vạch.
    final phase = (_controller.value + index * 0.1) % 1;
    final factor = reduced
        ? 0.5
        : 0.28 + 0.72 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));
    return Container(
      width: widget.barWidth,
      height: widget.height * factor,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: SfRadius.pillR,
      ),
    );
  }
}

/// Biểu đồ cột đơn giản — giờ lái theo tuần, diễn biến tỉnh táo 60 phút.
class SfBarChart extends StatelessWidget {
  const SfBarChart({
    required this.values,
    super.key,
    this.labels = const <String>[],
    this.colors = const <Color>[],
    this.height = 120,
    this.maxValue,
    this.barRadius = 6,
    this.valueLabels = const <String>[],
  });

  final List<double> values;
  final List<String> labels;

  /// Màu từng cột; thiếu thì dùng màu nhấn.
  final List<Color> colors;
  final double height;
  final double? maxValue;
  final double barRadius;
  final List<String> valueLabels;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final peak =
        maxValue ?? (values.isEmpty ? 1.0 : values.reduce(math.max));
    final safePeak = peak <= 0 ? 1.0 : peak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (i < valueLabels.length)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              valueLabels[i],
                              style: SfType.chip.copyWith(
                                color: p.textMuted,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        Container(
                          height: math.max(
                            4.0,
                            (height - 22) * (values[i] / safePeak),
                          ),
                          decoration: BoxDecoration(
                            color: i < colors.length ? colors[i] : p.accent,
                            borderRadius: BorderRadius.circular(barRadius),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: SfSpace.x8),
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: SfType.caption.copyWith(color: p.textMuted),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Nền kính mờ — dock nổi, thẻ chỉ dẫn trong chế độ lái.
class SfBlur extends StatelessWidget {
  const SfBlur({
    required this.child,
    super.key,
    this.sigma = 12,
    this.borderRadius = SfRadius.dockR,
  });

  final Widget child;
  final double sigma;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    ),
  );
}

/// Ô vuông tick 28px của checklist trước chuyến.
class SfCheckBox extends StatelessWidget {
  const SfCheckBox({required this.checked, super.key, this.size = 28});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: SfMotion.of(context, SfMotion.dToggle),
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: checked ? SfColors.green700 : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(
        color: checked ? SfColors.green700 : const Color(0xFFCBD8D0),
        width: 1.5,
      ),
    ),
    child: Icon(
      checked ? Icons.check_rounded : Icons.remove_rounded,
      size: size * 0.62,
      color: checked ? SfColors.onAccent : const Color(0xFFCBD8D0),
    ),
  );
}
