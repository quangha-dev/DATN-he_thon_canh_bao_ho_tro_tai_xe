import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'sf_status.dart';

/// Mức cảnh báo giờ lái liên tục, theo rule giờ lái của hệ thống
/// (mặc định 180 / 210 / 230 / 240 phút).
enum SfDrivingBand { normal, warning1, warning2, critical, overLimit }

extension SfDrivingBandLabel on SfDrivingBand {
  String get label => switch (this) {
    SfDrivingBand.normal => 'Trong ngưỡng',
    SfDrivingBand.warning1 => 'Sắp tới hạn',
    SfDrivingBand.warning2 => 'Cần chuẩn bị nghỉ',
    SfDrivingBand.critical => 'Phải nghỉ ngay',
    SfDrivingBand.overLimit => 'Đã quá giới hạn',
  };

  SfStatus get status => switch (this) {
    SfDrivingBand.normal => SfStatus.good,
    SfDrivingBand.warning1 => SfStatus.pending,
    SfDrivingBand.warning2 => SfStatus.warning,
    SfDrivingBand.critical || SfDrivingBand.overLimit => SfStatus.danger,
  };
}

/// Thanh giờ lái liên tục có vạch mốc.
///
/// Đây là con số quyết định của một ca lái: tài xế cần biết còn bao lâu nữa
/// thì bắt buộc phải nghỉ, đọc được bằng một cái liếc mắt.
class SfDrivingHoursBar extends StatelessWidget {
  const SfDrivingHoursBar({
    required this.continuousMinutes,
    super.key,
    this.maxMinutes = 240,
    this.warning1Minutes = 180,
    this.warning2Minutes = 210,
    this.criticalMinutes = 230,
    this.drive = false,
  });

  final int continuousMinutes;
  final int maxMinutes;
  final int warning1Minutes;
  final int warning2Minutes;
  final int criticalMinutes;

  /// Cỡ chữ chế độ lái (sàn 18px).
  final bool drive;

  SfDrivingBand get band {
    if (continuousMinutes >= maxMinutes) return SfDrivingBand.overLimit;
    if (continuousMinutes >= criticalMinutes) return SfDrivingBand.critical;
    if (continuousMinutes >= warning2Minutes) return SfDrivingBand.warning2;
    if (continuousMinutes >= warning1Minutes) return SfDrivingBand.warning1;
    return SfDrivingBand.normal;
  }

  int get remainingMinutes =>
      math.max(0, maxMinutes - continuousMinutes);

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final ink = band.status.inkOf(p);
    final ratio = maxMinutes == 0
        ? 0.0
        : (continuousMinutes / maxMinutes).clamp(0.0, 1.0);
    final metaStyle = SfType.meta.copyWith(
      color: p.textSecondary,
      fontSize: drive ? SfTouch.driveFontFloor : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$continuousMinutes',
              style: (drive ? SfType.displayDrive : SfType.titleScreen)
                  .copyWith(color: ink),
            ),
            const SizedBox(width: SfSpace.x4),
            Padding(
              padding: const EdgeInsets.only(bottom: SfSpace.x4),
              child: Text('/ $maxMinutes phút', style: metaStyle),
            ),
            const Spacer(),
            SfStatusPill(band.label, status: band.status, dense: true),
          ],
        ),
        const SizedBox(height: SfSpace.x12),
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: 14,
            child: Stack(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: SfRadius.pillR,
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: SfRadius.pillR,
                    ),
                  ),
                ),
                for (final tick in [
                  warning1Minutes,
                  warning2Minutes,
                  criticalMinutes,
                ])
                  if (maxMinutes > 0 && tick < maxMinutes)
                    Positioned(
                      left: constraints.maxWidth * (tick / maxMinutes) - 1,
                      child: Container(
                        width: 2,
                        height: 14,
                        color: p.isDark
                            ? SfColors.darkBg
                            : SfColors.surface,
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SfSpace.x8),
        Text(
          band == SfDrivingBand.overLimit
              ? 'Đã lái quá $maxMinutes phút liên tục. Dừng nghỉ trước khi đi tiếp.'
              : 'Còn $remainingMinutes phút trước khi bắt buộc nghỉ.',
          style: metaStyle,
        ),
      ],
    );
  }
}

/// Vòng điểm an toàn 0–100.
///
/// Dưới 50 điểm hệ thống chuyển tài xế sang nhóm rủi ro cao, nên ba dải màu
/// bám đúng ngưỡng nghiệp vụ: >= 80 tốt, >= 50 cần chú ý, < 50 nguy hiểm.
class SfScoreRing extends StatelessWidget {
  const SfScoreRing({
    required this.score,
    super.key,
    this.size = 92,
    this.caption = 'điểm an toàn',
    this.max = 100,
    this.invert = false,
    this.decimals = 0,
  });

  final num score;
  final double size;
  final String caption;

  /// Giá trị lớn nhất của thang đo (100 cho điểm an toàn, 10 cho nguy cơ).
  final num max;

  /// Đặt true khi điểm cao là xấu — ví dụ thang nguy cơ buồn ngủ.
  final bool invert;

  final int decimals;

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
    final ink = status.inkOf(p);
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
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: p.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(ink),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(decimals),
                style: SfType.titleScreen.copyWith(color: p.textPrimary),
              ),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: SfType.label.copyWith(color: p.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
