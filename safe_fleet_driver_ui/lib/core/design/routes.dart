import 'package:flutter/material.dart';

import 'motion.dart';
import 'tokens.dart';

/// Đẩy màn con: màn mới vào từ phải, màn cũ lùi 4% và tối đi 12% — có chiều sâu.
class SfSlideRoute<T> extends PageRouteBuilder<T> {
  SfSlideRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: SfMotion.dPush,
        reverseTransitionDuration: SfMotion.dPush,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, secondary, child) {
          if (MediaQuery.disableAnimationsOf(context)) {
            return FadeTransition(opacity: animation, child: child);
          }
          final enter = CurvedAnimation(
            parent: animation,
            curve: SfMotion.standard,
            reverseCurve: SfMotion.exit,
          );
          final leave = CurvedAnimation(
            parent: secondary,
            curve: SfMotion.standard,
          );
          return SlideTransition(
            position: Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(enter),
            child: SlideTransition(
              position: Tween(
                begin: Offset.zero,
                end: const Offset(-0.04, 0),
              ).animate(leave),
              child: AnimatedBuilder(
                animation: leave,
                builder: (context, inner) => ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    SfColors.navy.withValues(alpha: 0.12 * leave.value),
                    BlendMode.srcATop,
                  ),
                  child: inner,
                ),
                child: child,
              ),
            ),
          );
        },
      );
}

/// Thẻ chuyến → chi tiết chuyến: thẻ giãn từ đúng vị trí đã bấm ra toàn màn,
/// bo góc nội suy 20 → 0. Dùng kèm [Hero] trên mã chuyến.
class SfMorphRoute<T> extends PageRouteBuilder<T> {
  SfMorphRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: SfMotion.dMorph,
        reverseTransitionDuration: SfMotion.dMorph,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.disableAnimationsOf(context)) {
            return FadeTransition(opacity: animation, child: child);
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: SfMotion.standard,
            reverseCurve: SfMotion.exit,
          );
          return AnimatedBuilder(
            animation: curved,
            builder: (context, inner) => Opacity(
              opacity: curved.value,
              child: Transform.scale(
                scale: 0.94 + 0.06 * curved.value,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    SfRadius.card * (1 - curved.value),
                  ),
                  child: inner,
                ),
              ),
            ),
            child: child,
          );
        },
      );
}

/// Chi tiết → Chế độ lái: bản đồ zoom vào từ 0.94 + fade, 380ms.
class SfDriveRoute<T> extends PageRouteBuilder<T> {
  SfDriveRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: SfMotion.dDrive,
        reverseTransitionDuration: SfMotion.dPush,
        opaque: true,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.disableAnimationsOf(context)) {
            return FadeTransition(opacity: animation, child: child);
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: SfMotion.standard,
            reverseCurve: SfMotion.exit,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
}
