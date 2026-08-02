import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/tokens.dart';
import 'sf_card.dart';

/// Khung màn chuẩn: tiêu đề + phụ đề + hành động, padding thống nhất, và một
/// chỗ duy nhất xử lý loading / empty / error cho mọi màn.
class SfScreenScaffold extends StatelessWidget {
  const SfScreenScaffold({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.trailing,
    this.padding = SfSpace.screen,
    this.scrollable = true,
    this.floating,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final bool scrollable;
  final Widget? floating;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.only(bottom: SfSpace.x20),
      child: SfScreenTitle(
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );

    Widget body = scrollable
        ? SingleChildScrollView(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, child],
            ),
          )
        : Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, Expanded(child: child)],
            ),
          );

    if (onRefresh != null) {
      body = RefreshIndicator(onRefresh: onRefresh!, child: body);
    }

    return Scaffold(
      backgroundColor: context.sf.bg,
      body: SafeArea(bottom: false, child: body),
      floatingActionButton: floating,
    );
  }

  /// Dựng phần thân từ một [AsyncSnapshot]-like: loading → skeleton,
  /// lỗi → nói chuyện gì xảy ra + làm gì tiếp, rỗng → [SfEmptyState].
  static Widget state({
    required bool loading,
    required Object? error,
    required bool isEmpty,
    required Widget Function() builder,
    Widget? empty,
    VoidCallback? onRetry,
    int skeletonCards = 3,
  }) {
    if (loading) {
      return Column(
        children: [
          for (var i = 0; i < skeletonCards; i++) ...[
            SfSkeleton.card(),
            if (i != skeletonCards - 1) const SizedBox(height: SfSpace.x12),
          ],
        ],
      );
    }
    if (error != null) {
      return SfEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Chưa tải được dữ liệu',
        message: '$error\nKiểm tra kết nối rồi thử lại.',
        action: onRetry == null
            ? null
            : TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      );
    }
    if (isEmpty) {
      return empty ??
          const SfEmptyState(
            icon: Icons.inbox_rounded,
            title: 'Chưa có dữ liệu',
            message: 'Mục này sẽ hiện khi có bản ghi mới.',
          );
    }
    return builder();
  }
}

/// Tiêu đề màn: một thông tin quan trọng nhất, to nhất.
class SfScreenTitle extends StatelessWidget {
  const SfScreenTitle({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SfType.titleScreen.copyWith(color: p.textPrimary),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: SfSpace.x4),
                Text(
                  subtitle!,
                  style: SfType.meta.copyWith(color: p.textSecondary),
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
    );
  }
}

/// Bottom sheet 3 mức snap: peek / nửa / toàn phần.
///
/// Bám ngón tay khi kéo, snap theo vận tốc. Nội dung nền (bản đồ) tự mờ và
/// thu nhỏ khi sheet lên mức cao nhất — xem [SfSheetScope.progress].
class SfSheet extends StatelessWidget {
  const SfSheet({
    required this.builder,
    super.key,
    this.snaps = const [0.22, 0.55, 0.92],
    this.controller,
  });

  final Widget Function(BuildContext context, ScrollController scroll) builder;
  final List<double> snaps;
  final DraggableScrollableController? controller;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: snaps.first,
      minChildSize: snaps.first,
      maxChildSize: snaps.last,
      snap: true,
      snapSizes: snaps.sublist(1, snaps.length - 1),
      builder: (context, scroll) => DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: SfRadius.sheetR,
          boxShadow: SfShadow.floating,
        ),
        child: ClipRRect(
          borderRadius: SfRadius.sheetR,
          child: Column(
            children: [
              const _SheetHandle(),
              Expanded(child: builder(context, scroll)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: SfSpace.x12),
    child: Container(
      height: 4,
      width: 44,
      decoration: BoxDecoration(
        color: context.sf.border,
        borderRadius: SfRadius.pillR,
      ),
    ),
  );
}

/// Fade + trượt lên 10px với độ trễ so le — dùng khi đổi tab dock.
///
/// Không trượt ngang: trong tầm mắt tài xế không có gì được trượt ngang.
class SfStaggeredIn extends StatelessWidget {
  const SfStaggeredIn({
    required this.child,
    required this.index,
    super.key,
    this.trigger,
  });

  final Widget child;
  final int index;

  /// Đổi giá trị này để chạy lại hiệu ứng (ví dụ chỉ số tab đang chọn).
  final Object? trigger;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(trigger),
    tween: Tween(begin: 0, end: 1),
    duration:
        SfMotion.of(context, SfMotion.dTab) + SfMotion.staggerOf(context, index),
    curve: SfMotion.curveOf(context, SfMotion.standard),
    builder: (context, value, child) => Opacity(
      opacity: value.clamp(0, 1),
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}
