import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'sf_card.dart';
import 'sf_status.dart';
import 'sf_surfaces.dart';

/// Một ô số liệu nhỏ trong hàng dưới của thẻ chuyến.
class SfTripMetric {
  const SfTripMetric(this.label, this.value, {this.icon});

  final String label;
  final String value;
  final IconData? icon;
}

/// Thẻ chuyến — nền tảng cho mọi danh sách chuyến.
///
/// Thứ tự đọc: hàng chip trạng thái + mã chuyến → tuyến đường (to nhất) →
/// dòng mô tả hàng hoá / quãng đường → giờ đi–đến → thanh tiến độ.
class SfTripCard extends StatelessWidget {
  const SfTripCard({
    required this.code,
    required this.origin,
    required this.destination,
    super.key,
    this.status = SfStatus.pending,
    this.statusLabel,
    this.riskLabel,
    this.summary,
    this.departAt,
    this.arriveAt,
    this.progress,
    this.metrics = const [],
    this.onTap,
    this.heroTag,
    this.emphasized = false,
    this.footer,
  });

  final String code;
  final String origin;
  final String destination;
  final SfStatus status;
  final String? statusLabel;

  /// Nhãn rủi ro nền hổ phách — "RỦI RO CAO".
  final String? riskLabel;

  /// "32,5 km · hàng lạnh · 2 điểm ngập trên tuyến"
  final String? summary;

  final String? departAt;
  final String? arriveAt;

  /// 0..1 — chỉ hiện với chuyến đang chạy.
  final double? progress;

  final List<SfTripMetric> metrics;
  final VoidCallback? onTap;

  /// Thẻ đang chạy dùng Hero để giãn ra toàn màn khi mở chi tiết.
  final Object? heroTag;

  /// Chuyến đang chạy: viền màu trạng thái 1.5px.
  final bool emphasized;

  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final codeText = Text(
      code,
      style: SfType.mono.copyWith(
        color: p.textMuted,
        fontWeight: FontWeight.w600,
      ),
    );

    return SfCard(
      onTap: onTap,
      emphasis: emphasized ? status : null,
      borderColor: emphasized ? SfColors.green700 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SfStatusPill(
                statusLabel ?? _defaultLabel(status),
                status: status,
              ),
              if (riskLabel != null) ...[
                const SizedBox(width: SfSpace.x8),
                SfStatusPill.amber(riskLabel!),
              ],
              const Spacer(),
              heroTag == null
                  ? codeText
                  : Hero(
                      tag: heroTag!,
                      child: Material(
                        color: Colors.transparent,
                        child: codeText,
                      ),
                    ),
            ],
          ),
          const SizedBox(height: SfSpace.x12),
          _RouteLine(origin: origin, destination: destination),
          if (summary != null && summary!.isNotEmpty) ...[
            const SizedBox(height: SfSpace.x8),
            Text(
              summary!,
              style: SfType.caption.copyWith(color: p.textMuted),
            ),
          ],
          if (departAt != null || arriveAt != null) ...[
            const SizedBox(height: SfSpace.x12),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: p.textMuted,
                ),
                const SizedBox(width: SfSpace.x4 + 2),
                Text(
                  [
                    ?departAt,
                    ?arriveAt,
                  ].join('  →  '),
                  style: SfType.mono.copyWith(
                    color: p.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: SfSpace.x12),
            SfProgressBar(value: progress!, color: SfColors.green700),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: SfSpace.x16),
            Row(
              children: [
                for (final metric in metrics)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.label.toUpperCase(),
                          style: SfType.label.copyWith(color: p.textMuted),
                        ),
                        const SizedBox(height: SfSpace.x4),
                        Row(
                          children: [
                            if (metric.icon != null) ...[
                              Icon(
                                metric.icon,
                                size: 14,
                                color: p.textSecondary,
                              ),
                              const SizedBox(width: SfSpace.x4),
                            ],
                            Flexible(
                              child: Text(
                                metric.value,
                                overflow: TextOverflow.ellipsis,
                                style: SfType.mono.copyWith(
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: SfSpace.x14),
            footer!,
          ],
        ],
      ),
    );
  }

  static String _defaultLabel(SfStatus status) => switch (status) {
    SfStatus.good => 'Đã xong',
    SfStatus.pending => 'Chờ đi',
    SfStatus.warning => 'Cần chú ý',
    SfStatus.danger => 'Sự cố',
  };
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.origin, required this.destination});

  final String origin;
  final String destination;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            origin,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SfType.titleCard.copyWith(color: p.textPrimary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SfSpace.x8),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: SfColors.green700,
          ),
        ),
        Flexible(
          child: Text(
            destination,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SfType.titleCard.copyWith(color: p.textPrimary),
          ),
        ),
      ],
    );
  }
}
