import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'sf_card.dart';
import 'sf_status.dart';

/// Một ô số liệu nhỏ trong hàng dưới của thẻ chuyến.
class SfTripMetric {
  const SfTripMetric(this.label, this.value, {this.icon});

  final String label;
  final String value;
  final IconData? icon;
}

/// Thẻ chuyến — nền tảng cho mọi danh sách chuyến.
///
/// Thứ tự đọc: mã chuyến (mono) + trạng thái bên phải → tuyến đường (to nhất)
/// → tài xế / biển số → hàng 2–3 số liệu.
class SfTripCard extends StatelessWidget {
  const SfTripCard({
    required this.code,
    required this.origin,
    required this.destination,
    super.key,
    this.status = SfStatus.pending,
    this.statusLabel,
    this.driver,
    this.plate,
    this.metrics = const [],
    this.onTap,
    this.heroTag,
    this.emphasized = false,
  });

  final String code;
  final String origin;
  final String destination;
  final SfStatus status;
  final String? statusLabel;
  final String? driver;
  final String? plate;
  final List<SfTripMetric> metrics;
  final VoidCallback? onTap;

  /// Thẻ đang chạy dùng Hero để giãn ra toàn màn khi mở chi tiết.
  final Object? heroTag;

  /// Chuyến đang chạy: viền + dải màu trạng thái trên đỉnh.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final codeText = Text(
      code,
      style: SfType.mono.copyWith(
        color: p.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );

    return SfCard(
      onTap: onTap,
      emphasis: emphasized ? status : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: heroTag == null
                    ? codeText
                    : Hero(
                        tag: heroTag!,
                        child: Material(
                          color: Colors.transparent,
                          child: codeText,
                        ),
                      ),
              ),
              SfStatusPill(
                statusLabel ?? _defaultLabel(status),
                status: status,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x12),
          _RouteLine(origin: origin, destination: destination),
          if (driver != null || plate != null) ...[
            const SizedBox(height: SfSpace.x8),
            Text(
              [
                if (driver != null) driver!,
                if (plate != null) plate!,
              ].join(' · '),
              style: SfType.meta.copyWith(color: p.textSecondary),
            ),
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
        ],
      ),
    );
  }

  static String _defaultLabel(SfStatus status) => switch (status) {
    SfStatus.good => 'Hoàn thành',
    SfStatus.pending => 'Chờ',
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            origin,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SfType.titleCard.copyWith(color: p.textPrimary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SfSpace.x8),
          child: Icon(Icons.arrow_forward_rounded, size: 18, color: p.accent),
        ),
        Expanded(
          child: Text(
            destination,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SfType.titleCard.copyWith(color: p.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// Một mốc trên dòng thời gian.
class SfTimelineEntry {
  const SfTimelineEntry({
    required this.title,
    this.meta,
    this.status = SfStatus.pending,
    this.done = false,
  });

  final String title;
  final String? meta;
  final SfStatus status;
  final bool done;
}

/// Chấm + đường nối: mốc chuyến, log cảnh báo, timeline sự cố.
class SfTimeline extends StatelessWidget {
  const SfTimeline({required this.entries, super.key});

  final List<SfTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
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
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: SfSpace.x4),
                      decoration: BoxDecoration(
                        color: entries[i].done
                            ? entries[i].status.inkOf(p)
                            : p.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: entries[i].status.inkOf(p),
                          width: 2,
                        ),
                      ),
                    ),
                    if (i != entries.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: p.border,
                          margin: const EdgeInsets.symmetric(
                            vertical: SfSpace.x4,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: SfSpace.x12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == entries.length - 1 ? 0 : SfSpace.x16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entries[i].title,
                          style: SfType.body.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (entries[i].meta != null) ...[
                          const SizedBox(height: SfSpace.x4),
                          Text(
                            entries[i].meta!,
                            style: SfType.meta.copyWith(
                              color: p.textSecondary,
                            ),
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
