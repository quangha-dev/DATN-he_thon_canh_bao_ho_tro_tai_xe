import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'sf_status.dart';
import 'sf_surfaces.dart';

/// Mức cảnh báo giờ lái liên tục.
///
/// Ngưỡng theo bản thiết kế: dưới 180 phút an toàn, 180–229 phút cảnh báo,
/// từ 230 phút là nghiêm trọng; giới hạn cứng 240 phút (4 giờ).
enum SfDrivingBand { normal, warning, critical }

extension SfDrivingBandLabel on SfDrivingBand {
  SfStatus get status => switch (this) {
    SfDrivingBand.normal => SfStatus.good,
    SfDrivingBand.warning => SfStatus.warning,
    SfDrivingBand.critical => SfStatus.danger,
  };

  String get label => switch (this) {
    SfDrivingBand.normal => 'Nhịp lái an toàn',
    SfDrivingBand.warning => 'Sắp chạm giới hạn',
    SfDrivingBand.critical => 'Phải nghỉ ngay',
  };

  IconData get icon => switch (this) {
    SfDrivingBand.normal => Icons.coffee_rounded,
    SfDrivingBand.warning => Icons.coffee_rounded,
    SfDrivingBand.critical => Icons.warning_amber_rounded,
  };
}

/// Thanh giờ lái liên tục có vạch mốc 3h / 3h30 / 4h.
///
/// Đây là con số quyết định của một ca lái: tài xế cần biết còn bao lâu nữa
/// thì bắt buộc phải nghỉ, đọc được bằng một cái liếc mắt. Màu và câu khuyên
/// đổi theo ngưỡng.
class SfDrivingHoursBar extends StatelessWidget {
  const SfDrivingHoursBar({
    required this.continuousMinutes,
    super.key,
    this.maxMinutes = 240,
    this.remindMinutes = 180,
    this.warnMinutes = 210,
    this.criticalMinutes = 230,
    this.drive = false,
    this.showAdvice = true,
  });

  final int continuousMinutes;
  final int maxMinutes;

  /// 3h — nhắc nghỉ.
  final int remindMinutes;

  /// 3h30 — cảnh báo.
  final int warnMinutes;

  /// Ngưỡng nghiêm trọng.
  final int criticalMinutes;

  /// Cỡ chữ chế độ lái (sàn 18px).
  final bool drive;

  /// Hiện khối lời khuyên bên dưới thanh.
  final bool showAdvice;

  SfDrivingBand get band {
    if (continuousMinutes >= criticalMinutes) return SfDrivingBand.critical;
    if (continuousMinutes >= remindMinutes) return SfDrivingBand.warning;
    return SfDrivingBand.normal;
  }

  int get remainingMinutes => math.max(0, maxMinutes - continuousMinutes);

  /// "2h52 / 4h"
  String get readout {
    final h = continuousMinutes ~/ 60;
    final m = continuousMinutes % 60;
    final limitH = maxMinutes ~/ 60;
    return '${h}h${m.toString().padLeft(2, '0')} / ${limitH}h';
  }

  String get advice => switch (band) {
    SfDrivingBand.normal =>
      'Nhịp lái đang an toàn. Nghỉ 15 phút sau mỗi 3 giờ liên tục.',
    SfDrivingBand.warning =>
      'Còn $remainingMinutes phút là chạm giới hạn '
          '${maxMinutes ~/ 60} giờ. Nên nghỉ 15 phút.',
    SfDrivingBand.critical =>
      'Đã vượt ngưỡng nghiêm trọng. Tấp vào lề và nghỉ ngay.',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final status = band.status;
    final ink = status.inkOf(p);
    final ratio = maxMinutes == 0
        ? 0.0
        : (continuousMinutes / maxMinutes).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Giờ lái liên tục',
                style: SfType.titleCardSm.copyWith(
                  color: p.textPrimary,
                  fontSize: drive ? SfTouch.driveFontFloor : null,
                ),
              ),
            ),
            Text(
              readout,
              style: SfType.mono.copyWith(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: drive ? SfTouch.driveFontFloor : 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: SfSpace.x10),
        SfProgressBar(
          value: ratio,
          height: 12,
          color: ink,
          ticks: [
            remindMinutes / maxMinutes,
            warnMinutes / maxMinutes,
            criticalMinutes / maxMinutes,
          ],
        ),
        if (showAdvice) ...[
          const SizedBox(height: SfSpace.x12),
          SfInfoBox(
            icon: band.icon,
            text: advice,
            status: status,
          ),
        ],
      ],
    );
  }
}

/// Vòng điểm an toàn 0–100 — số lớn ở giữa, nhãn VIẾT HOA bên dưới.
///
/// Vẽ bằng cung tròn dày (tương đương `conic-gradient` của bản thiết kế).
class SfScoreRing extends StatelessWidget {
  const SfScoreRing({
    required this.score,
    super.key,
    this.size = 92,
    this.caption = 'ĐIỂM',
    this.max = 100,
    this.invert = false,
    this.decimals = 0,
    this.strokeWidth,
    this.color,
    this.trackColor,
    this.onDark = false,
  });

  final num score;
  final double size;
  final String caption;

  /// Giá trị lớn nhất của thang đo (100 cho điểm an toàn, 10 cho nguy cơ).
  final num max;

  /// Đặt true khi điểm cao là xấu — ví dụ thang nguy cơ buồn ngủ.
  final bool invert;

  final int decimals;
  final double? strokeWidth;
  final Color? color;
  final Color? trackColor;
  final bool onDark;

  /// Ngưỡng bám theo rule nghiệp vụ: dưới 50 điểm tài xế bị chuyển sang nhóm
  /// rủi ro cao.
  static SfStatus statusOf(num score, {num max = 100, bool invert = false}) {
    final ratio = max == 0 ? 0.0 : (score / max).clamp(0.0, 1.0);
    final good = invert ? 1 - ratio : ratio;
    if (good >= 0.8) return SfStatus.good;
    if (good >= 0.65) return SfStatus.pending;
    if (good >= 0.5) return SfStatus.warning;
    return SfStatus.danger;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final status = statusOf(score, max: max, invert: invert);
    final ink = color ?? (onDark ? SfColors.green400 : status.inkOf(p));
    final track =
        trackColor ??
        (onDark
            ? SfColors.onAccent.withValues(alpha: 0.18)
            : (p.isDark ? p.surfaceAlt : SfColors.divider));
    final textInk = onDark ? SfColors.onAccent : p.textPrimary;
    final captionInk = onDark
        ? SfColors.onAccent.withValues(alpha: 0.72)
        : p.textMuted;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: max == 0 ? 0 : (score / max).clamp(0.0, 1.0).toDouble(),
              strokeWidth: strokeWidth ?? size * 0.115,
              strokeCap: StrokeCap.round,
              backgroundColor: track,
              valueColor: AlwaysStoppedAnimation<Color>(ink),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(decimals),
                style: SfType.stat.copyWith(
                  color: textInk,
                  fontSize: size * 0.27,
                ),
              ),
              if (caption.isNotEmpty)
                Text(
                  caption.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: SfType.chip.copyWith(
                    color: captionInk,
                    fontSize: math.max(8.0, size * 0.105),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
