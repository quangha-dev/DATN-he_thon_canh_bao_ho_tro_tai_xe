import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/cabin_ai_controller.dart';
import '../../core/ai/cabin_safety_provider.dart';
import '../../core/ai/temporal_safety_engine.dart';
import '../../core/widgets/ui.dart';

/// Camera cabin — luôn nền tối vì màn này sống trong cabin, phần lớn là ban đêm.
///
/// Ba cấp cảnh báo dùng đúng ngôn ngữ thị giác của [SfAlertBanner]; điểm nguy cơ
/// và mọi chỉ số đều là dữ liệu engine đang chạy, không suy diễn thêm.
class CabinCameraScreen extends ConsumerWidget {
  const CabinCameraScreen({super.key});

  /// Ngưỡng của engine: 6.0 là nguy hiểm, 3.5 là bắt đầu có dấu hiệu.
  static const _dangerScore = 6.0;
  static const _cautionScore = 3.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cabinSafetyProvider);
    final notifier = ref.read(cabinSafetyProvider.notifier);
    final metrics = state.metrics;
    final camera = notifier.cameraController;

    return Theme(
      data: SfTheme.dark,
      child: Scaffold(
        backgroundColor: SfColors.darkBg,
        appBar: AppBar(
          backgroundColor: SfColors.darkBg,
          title: const Text('Giám sát tỉnh táo'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: SfSpace.x12),
              child: Switch.adaptive(
                value: state.enabled,
                onChanged: (_) => notifier.toggle(),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            SfSpace.x16,
            SfSpace.x8,
            SfSpace.x16,
            SfSpace.x32,
          ),
          children: [
            _alertBanner(state, metrics, notifier),
            const SizedBox(height: SfSpace.x16),
            _CameraPanel(
              camera: camera,
              enabled: state.enabled,
              metrics: metrics,
            ),
            const SizedBox(height: SfSpace.x16),
            _StatusPanel(
              enabled: state.enabled,
              message: state.message,
              metrics: metrics,
            ),
            const SizedBox(height: SfSpace.x12),
            _ScorePanel(metrics: metrics),
            const SizedBox(height: SfSpace.x24),
            const SfSectionLabel('Chỉ số đo trực tiếp'),
            const SizedBox(height: SfSpace.x12),
            _MetricGrid(metrics: metrics),
            const SizedBox(height: SfSpace.x24),
            const SfSectionLabel('Diễn biến nguy cơ'),
            const SizedBox(height: SfSpace.x12),
            _TrendPanel(metrics: metrics),
            const SizedBox(height: SfSpace.x24),
            _privacyNote(),
          ],
        ),
      ),
    );
  }

  /// Cấp 0 khi tỉnh táo, cấp 1 khi có dấu hiệu, cấp 2 khi vượt ngưỡng nguy hiểm.
  Widget _alertBanner(
    CabinSafetyState state,
    CabinMetrics? metrics,
    CabinSafetyController notifier,
  ) {
    final detection = state.lastDetection;
    final score = metrics?.score ?? 0;
    final source = detection == null
        ? state.modelMode.label
        : '${state.modelMode.label} · ${detection.source}';

    if (!state.enabled) {
      return SfAlertBanner(
        level: SfAlertLevel.calm,
        title: 'Giám sát đang tắt',
        message:
            'Bật công tắc ở góc trên để camera bắt đầu theo dõi dấu hiệu buồn ngủ.',
        source: state.modelMode.label,
      );
    }

    if (score >= _dangerScore || detection?.severity == 'CRITICAL') {
      return SfAlertBanner(
        level: SfAlertLevel.critical,
        title: 'Dừng xe ngay',
        message:
            '${detection?.reason ?? 'Nguy cơ buồn ngủ vượt ngưỡng an toàn.'}\n'
            'Đã báo tổng đài. Tấp vào lề, tắt máy và nghỉ ít nhất 15 phút.',
        source: source,
        primaryLabel: 'Tôi sẽ nghỉ ngay',
        onPrimary: notifier.acknowledgeDetection,
      );
    }

    if (score >= _cautionScore || detection != null) {
      return SfAlertBanner(
        level: SfAlertLevel.caution,
        title: 'Có dấu hiệu buồn ngủ',
        message:
            '${detection?.reason ?? metrics?.statusText ?? 'Nhịp chớp mắt đang chậm dần.'}\n'
            'Tìm chỗ dừng an toàn trong 10 phút tới.',
        source: source,
        onDismiss: notifier.acknowledgeDetection,
      );
    }

    return SfAlertBanner(
      level: SfAlertLevel.calm,
      title: 'Tỉnh táo · nguy cơ ${score.toStringAsFixed(1)}/10',
      message:
          metrics?.statusText ?? 'Camera đang đo, chưa phát hiện dấu hiệu.',
      source: source,
    );
  }

  Widget _privacyNote() => SfCard(
    background: SfColors.darkSurfaceAlt,
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: SfColors.mint),
        SizedBox(width: SfSpace.x12),
        Expanded(child: _PrivacyText()),
      ],
    ),
  );
}

class _PrivacyText extends StatelessWidget {
  const _PrivacyText();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Xử lý trên máy, không gửi hình',
        style: SfType.titleCard.copyWith(color: SfColors.darkTextPrimary),
      ),
      const SizedBox(height: SfSpace.x4),
      Text(
        'Khung hình camera không rời khỏi điện thoại. Hệ thống chỉ đồng bộ sự kiện cảnh báo và chỉ số an toàn.',
        style: SfType.meta.copyWith(color: SfColors.darkTextSecondary),
      ),
    ],
  );
}

class _CameraPanel extends StatelessWidget {
  const _CameraPanel({
    required this.camera,
    required this.enabled,
    required this.metrics,
  });

  final CameraController? camera;
  final bool enabled;
  final CabinMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final locked = metrics?.faceDetected == true;
    return Container(
      height: 320,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SfColors.darkSurfaceAlt,
        borderRadius: SfRadius.cardR,
        border: Border.all(color: SfColors.darkBorder),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null && camera!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: camera!.value.previewSize?.height ?? 1,
                height: camera!.value.previewSize?.width ?? 1,
                child: CameraPreview(camera!),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled
                        ? Icons.hourglass_top_rounded
                        : Icons.videocam_off_outlined,
                    color: SfColors.darkTextSecondary,
                    size: 52,
                  ),
                  const SizedBox(height: SfSpace.x12),
                  Text(
                    enabled
                        ? 'Đang chuẩn bị camera'
                        : 'Bật công tắc để bắt đầu giám sát',
                    style: SfType.body.copyWith(
                      color: SfColors.darkTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          if (enabled) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(SfSpace.x12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: locked
                          ? SfColors.mint.withValues(alpha: 0.75)
                          : SfColors.darkTextMuted.withValues(alpha: 0.45),
                      width: 2,
                    ),
                    borderRadius: SfRadius.cardR,
                  ),
                ),
              ),
            ),
            Positioned(
              top: SfSpace.x12,
              right: SfSpace.x12,
              child: SfStatusPill(
                locked ? 'Đang đo' : 'Tìm khuôn mặt',
                status: locked ? SfStatus.good : SfStatus.warning,
                icon: locked
                    ? Icons.fiber_manual_record_rounded
                    : Icons.search_rounded,
                dense: true,
              ),
            ),
            Positioned(
              left: SfSpace.x12,
              right: SfSpace.x12,
              bottom: SfSpace.x12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SfSpace.x12,
                  vertical: SfSpace.x8,
                ),
                decoration: BoxDecoration(
                  color: SfColors.darkBg.withValues(alpha: 0.72),
                  borderRadius: SfRadius.controlR,
                ),
                child: Text(
                  locked
                      ? 'Đã phát hiện khuôn mặt · không cần căn giữa.'
                      : 'Đưa toàn bộ khuôn mặt vào vùng camera.',
                  textAlign: TextAlign.center,
                  style: SfType.body.copyWith(color: SfColors.darkTextPrimary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.enabled,
    required this.message,
    required this.metrics,
  });

  final bool enabled;
  final String message;
  final CabinMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final calibrated = metrics?.calibrated == true;
    final progress = metrics == null
        ? 0.0
        : metrics!.calibrationProgress /
              math.max(1, metrics!.calibrationFrames);
    if (enabled && calibrated) return const SizedBox.shrink();

    return SfCard(
      background: SfColors.darkSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            enabled ? (metrics?.statusText ?? message) : 'Giám sát đang tắt',
            style: SfType.titleCard.copyWith(color: SfColors.darkTextPrimary),
          ),
          if (enabled && !calibrated) ...[
            const SizedBox(height: SfSpace.x12),
            ClipRRect(
              borderRadius: SfRadius.pillR,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: SfColors.darkSurfaceAlt,
                valueColor: const AlwaysStoppedAnimation<Color>(SfColors.mint),
              ),
            ),
            const SizedBox(height: SfSpace.x8),
            Text(
              'Hiệu chuẩn ${(progress * 100).round()}%. Nhìn thẳng, mở mắt tự nhiên.',
              style: SfType.meta.copyWith(color: SfColors.darkTextSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.metrics});

  final CabinMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final score = metrics?.score ?? 0;
    final predicted = metrics?.predictedScore ?? 0;
    return SfCard(
      background: SfColors.darkSurface,
      child: Row(
        children: [
          SfScoreRing(
            score: score,
            max: 10,
            invert: true,
            decimals: 1,
            caption: 'nguy cơ / 10',
          ),
          const SizedBox(width: SfSpace.x20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nguy cơ buồn ngủ',
                  style: SfType.titleCard.copyWith(
                    color: SfColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  'Ngưỡng cảnh báo 3.5 · ngưỡng nguy hiểm 6.0',
                  style: SfType.meta.copyWith(
                    color: SfColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: SfSpace.x12),
                Text(
                  'Dự báo sau 2 giây ${predicted.toStringAsFixed(1)}',
                  style: SfType.mono.copyWith(color: SfColors.darkTextPrimary),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  metrics == null
                      ? 'Chưa có dữ liệu đo'
                      : 'Xu hướng ${metrics!.trend >= 0 ? '+' : ''}${metrics!.trend.toStringAsFixed(2)} mỗi lần đo',
                  style: SfType.mono.copyWith(
                    color: SfColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final CabinMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData)>[
      (
        'EAR · mắt',
        metrics?.ear?.toStringAsFixed(3) ?? '—',
        Icons.remove_red_eye_outlined,
      ),
      (
        'MAR · miệng',
        metrics?.mar?.toStringAsFixed(3) ?? '—',
        Icons.face_retouching_natural,
      ),
      (
        'Iris',
        metrics == null ? '—' : metrics!.iris.toStringAsFixed(3),
        Icons.center_focus_strong_rounded,
      ),
      (
        'Góc đầu',
        metrics == null
            ? '—'
            : '${metrics!.pitch.toStringAsFixed(0)}° / ${metrics!.yaw.toStringAsFixed(0)}°',
        Icons.explore_outlined,
      ),
      (
        'Tốc độ đo',
        metrics == null ? '—' : '${metrics!.fps.toStringAsFixed(1)} FPS',
        Icons.speed_rounded,
      ),
      (
        'Điểm model thô',
        metrics == null ? '—' : metrics!.rawScore.toStringAsFixed(1),
        Icons.memory_rounded,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: SfSpace.x12,
      crossAxisSpacing: SfSpace.x12,
      childAspectRatio: 2.05,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.all(SfSpace.x12),
            decoration: BoxDecoration(
              color: SfColors.darkSurface,
              borderRadius: SfRadius.controlR,
              border: Border.all(color: SfColors.darkBorder),
            ),
            child: Row(
              children: [
                Icon(item.$3, color: SfColors.mint, size: 22),
                const SizedBox(width: SfSpace.x8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1.toUpperCase(),
                        style: SfType.label.copyWith(
                          color: SfColors.darkTextMuted,
                        ),
                      ),
                      const SizedBox(height: SfSpace.x4),
                      Text(
                        item.$2,
                        style: SfType.mono.copyWith(
                          color: SfColors.darkTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.metrics});

  final CabinMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final values = metrics?.scoreHistory ?? const <double>[];
    final last = values.isEmpty ? 0.0 : values.last;
    return SfCard(
      background: SfColors.darkSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '60 lần suy luận gần nhất',
            style: SfType.meta.copyWith(color: SfColors.darkTextSecondary),
          ),
          const SizedBox(height: SfSpace.x16),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _ScoreChartPainter(
                values: values,
                line: SfScoreRing.statusOf(
                  last,
                  max: 10,
                  invert: true,
                ).inkOnDark,
                grid: SfColors.darkBorder,
                danger: SfColors.dangerHot,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  const _ScoreChartPainter({
    required this.values,
    required this.line,
    required this.grid,
    required this.danger,
  });

  final List<double> values;
  final Color line;
  final Color grid;
  final Color danger;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final score in [0.0, 3.5, 10.0]) {
      final y = size.height * (1 - score / 10);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Ngưỡng nguy hiểm vẽ bằng màu cảnh báo để đọc được cả khi ảnh xám.
    final dangerY = size.height * (1 - 6.0 / 10);
    canvas.drawLine(
      Offset(0, dangerY),
      Offset(size.width, dangerY),
      Paint()
        ..color = danger
        ..strokeWidth = 2,
    );

    final shown = values.length > 60
        ? values.sublist(values.length - 60)
        : values;
    if (shown.length < 2) return;
    final path = Path();
    for (var index = 0; index < shown.length; index++) {
      final x = size.width * index / (shown.length - 1);
      final y = size.height * (1 - shown[index].clamp(0.0, 10.0) / 10);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.line != line;
}
