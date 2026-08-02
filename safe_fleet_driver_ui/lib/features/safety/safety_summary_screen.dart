import 'package:flutter/material.dart';

import '../../core/widgets/ui.dart';
import '../../models/driver_models.dart';
import '../agent/agent_voice_sheet.dart';
import '../camera/cabin_camera_screen.dart';

class SafetySummaryScreen extends StatelessWidget {
  const SafetySummaryScreen({required this.data, super.key});

  final DriverBootstrap data;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final safety = data.safety;
    final config = data.config;
    final score = _int(safety['safetyScore']);
    final status = SfScoreRing.statusOf(score);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: const Text('Tổng kết an toàn')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _agentSheet(context),
        icon: const Icon(Icons.mic_none_rounded),
        label: const Text('Trợ lý'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SfSpace.x16,
          SfSpace.x8,
          SfSpace.x16,
          SfSpace.x40 + SfSpace.x40,
        ),
        children: [
          SfScreenTitle(
            title: 'Nhịp lái hôm nay',
            subtitle: 'Tính từ phiên lái và cảnh báo đã đồng bộ về máy chủ.',
            trailing: SfStatusPill(_scoreLabel(score), status: status),
          ),
          const SizedBox(height: SfSpace.x20),

          // Giờ lái liên tục đứng trước điểm an toàn: đây là con số ràng buộc
          // tài xế phải dừng, không phải con số để tự hào.
          const SfSectionLabel('Giờ lái liên tục'),
          const SizedBox(height: SfSpace.x8),
          SfCard(
            child: SfDrivingHoursBar(
              continuousMinutes: _int(safety['continuousDrivingMinutes']),
              maxMinutes: _int(config['maxContinuousDrivingMinutes'], 240),
              warning1Minutes: _int(config['warningLevel1Minutes'], 180),
              warning2Minutes: _int(config['warningLevel2Minutes'], 210),
              criticalMinutes: _int(config['criticalWarningMinutes'], 230),
            ),
          ),

          const SizedBox(height: SfSpace.x24),
          const SfSectionLabel('Điểm an toàn'),
          const SizedBox(height: SfSpace.x8),
          SfCard(
            emphasis: status == SfStatus.good ? null : status,
            child: Row(
              children: [
                SfScoreRing(score: score),
                const SizedBox(width: SfSpace.x20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _scoreLabel(score),
                        style: SfType.titleCard.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: SfSpace.x4),
                      Text(
                        _scoreAdvice(score),
                        style: SfType.meta.copyWith(color: p.textSecondary),
                      ),
                      const SizedBox(height: SfSpace.x12),
                      Text(
                        'Mỗi cảnh báo nghiêm trọng trừ tới 12 điểm. Dưới 50 điểm hệ thống chuyển bạn sang nhóm rủi ro cao.',
                        style: SfType.meta.copyWith(color: p.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: SfSpace.x24),
          const SfSectionLabel('Số liệu hôm nay'),
          const SizedBox(height: SfSpace.x8),
          SfCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SfMetric(
                        label: 'Đã lái',
                        value: '${_int(safety['drivingTimeTodayMinutes'])}',
                        unit: 'phút',
                      ),
                    ),
                    Expanded(
                      child: SfMetric(
                        label: 'Còn được lái',
                        value:
                            '${_int(safety['remainingContinuousDrivingMinutes'])}',
                        unit: 'phút',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SfSpace.x20),
                Row(
                  children: [
                    Expanded(
                      child: SfMetric(
                        label: 'Chuyến đã giao',
                        value: '${_int(safety['totalTrips'])}',
                      ),
                    ),
                    Expanded(
                      child: SfMetric(
                        label: 'Cảnh báo tích luỹ',
                        value: '${_int(safety['totalAlerts'])}',
                        valueColor: _int(safety['totalAlerts']) > 0
                            ? SfColors.amber
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: SfSpace.x24),
          const SfSectionLabel('Giám sát cabin'),
          const SizedBox(height: SfSpace.x8),
          SfCard(
            onTap: () => Navigator.push(
              context,
              SfSlideRoute<void>(builder: (_) => const CabinCameraScreen()),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, color: p.accent, size: 26),
                const SizedBox(width: SfSpace.x16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Camera chống buồn ngủ',
                        style: SfType.titleCard.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: SfSpace.x4),
                      Text(
                        'Xem chỉ số trực tiếp và bật/tắt giám sát.',
                        style: SfType.meta.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.textMuted),
              ],
            ),
          ),

          const SizedBox(height: SfSpace.x24),
          const SfSectionLabel('Khuyến nghị'),
          const SizedBox(height: SfSpace.x8),
          SfCard(
            child: SfTimeline(
              entries: const [
                SfTimelineEntry(
                  title: 'Nghỉ 15 phút trước khi chạm ngưỡng lái liên tục',
                  meta: 'Nghỉ sớm giữ nguyên điểm an toàn của bạn',
                  status: SfStatus.good,
                  done: true,
                ),
                SfTimelineEntry(
                  title: 'Không thao tác điện thoại khi xe đang chạy',
                  meta: 'Camera ghi nhận và gửi cảnh báo về điều hành',
                  status: SfStatus.warning,
                  done: true,
                ),
                SfTimelineEntry(
                  title: 'Báo điểm ngập ngay khi gặp',
                  meta: 'Giúp hệ thống tính lại tuyến cho cả đội xe',
                  status: SfStatus.pending,
                  done: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _int(Object? value, [int fallback = 0]) => switch (value) {
    final num number => number.round(),
    final String text => int.tryParse(text) ?? fallback,
    _ => fallback,
  };

  static String _scoreLabel(int score) {
    if (score >= 80) return 'An toàn';
    if (score >= 65) return 'Ổn định';
    if (score >= 50) return 'Cần chú ý';
    return 'Rủi ro cao';
  }

  static String _scoreAdvice(int score) {
    if (score >= 80) return 'Giữ nhịp lái như hiện tại.';
    if (score >= 65) return 'Vài cảnh báo gần đây đã trừ điểm.';
    if (score >= 50) return 'Nghỉ đúng lúc và hạn chế xao nhãng.';
    return 'Liên hệ điều hành trước khi nhận chuyến tiếp theo.';
  }

  Future<void> _agentSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AgentVoiceSheet(
        tripId: data.currentTrip?['id'] == null
            ? null
            : (data.currentTrip!['id'] as num).toInt(),
      ),
    );
  }
}
