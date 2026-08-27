import 'package:flutter/material.dart';

import '../../core/widgets/ui.dart';
import '../../models/driver_models.dart';
import '../agent/agent_voice_sheet.dart';
import '../camera/cabin_camera_screen.dart';

/// Tổng kết an toàn ngày.
///
/// Giờ lái liên tục đứng trước điểm an toàn: đây là con số ràng buộc tài xế
/// phải dừng, không phải con số để tự hào.
class SafetySummaryScreen extends StatelessWidget {
  const SafetySummaryScreen({required this.data, super.key});

  final DriverBootstrap data;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final safety = data.safety;
    final config = data.config;
    final score = _int(safety['safetyScore']);
    final alerts = _int(safety['totalAlerts']);

    return SfSubScreen(
      title: 'Tổng kết an toàn',
      subtitle: 'Nhịp lái hôm nay',
      trailing: SfIconButton(
        icon: Icons.mic_rounded,
        onHero: true,
        tooltip: 'Hỏi trợ lý',
        onTap: () => _agentSheet(context),
      ),
      headerBottom: _hero(score),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statRow(context, safety, alerts),
          const SizedBox(height: SfSpace.x18),
          const SfSectionLabel('Giờ lái liên tục'),
          const SizedBox(height: SfSpace.x10),
          SfCard(
            child: SfDrivingHoursBar(
              continuousMinutes: _int(safety['continuousDrivingMinutes']),
              maxMinutes: _int(config['maxContinuousDrivingMinutes'], 240),
              remindMinutes: _int(config['warningLevel1Minutes'], 180),
              warnMinutes: _int(config['warningLevel2Minutes'], 210),
              criticalMinutes: _int(config['criticalWarningMinutes'], 230),
            ),
          ),
          const SizedBox(height: SfSpace.x18),
          const SfSectionLabel('Diễn biến trong ngày'),
          const SizedBox(height: SfSpace.x10),
          SfCard(child: SfTimeline(entries: _dayTimeline(safety))),
          const SizedBox(height: SfSpace.x18),
          SfInfoBox(
            icon: Icons.lightbulb_rounded,
            title: 'Gợi ý cho ngày mai',
            text: _advice(score, alerts),
          ),
          const SizedBox(height: SfSpace.x14),
          SfCard(
            onTap: () => Navigator.push(
              context,
              SfSlideRoute<void>(builder: (_) => const CabinCameraScreen()),
            ),
            padding: const EdgeInsets.all(SfSpace.x14),
            child: SfListRow(
              padding: EdgeInsets.zero,
              icon: Icons.visibility_rounded,
              title: 'Camera chống buồn ngủ',
              subtitle: 'Xem chỉ số trực tiếp và bật/tắt giám sát',
              showChevron: true,
              titleColor: p.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Vòng điểm 104px + câu giải thích điểm bị trừ ở đâu.
  Widget _hero(int score) => Row(
    children: [
      SfScoreRing(
        score: score,
        size: 104,
        caption: 'TRÊN 100',
        onDark: true,
        color: SfColors.green300,
      ),
      const SizedBox(width: SfSpace.x18),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _scoreLabel(score),
              style: SfType.titleCard.copyWith(color: SfColors.onAccent),
            ),
            const SizedBox(height: SfSpace.x8),
            Text(
              _scoreAdvice(score),
              style: SfType.caption.copyWith(color: SfColors.green300),
            ),
          ],
        ),
      ),
    ],
  );

  /// Ba ô: giờ lái, km đã đi, số cảnh báo.
  Widget _statRow(
    BuildContext context,
    Map<String, dynamic> safety,
    int alerts,
  ) {
    final p = context.sf;
    return SfCard(
      child: Row(
        children: [
          Expanded(
            child: SfStatCell(
              value: _duration(_int(safety['drivingTimeTodayMinutes'])),
              label: 'Giờ lái',
              align: CrossAxisAlignment.center,
            ),
          ),
          Container(width: 1, height: 34, color: p.border),
          Expanded(
            child: SfStatCell(
              value: '${_int(safety['distanceTodayKm'])}',
              label: 'Km đã đi',
              align: CrossAxisAlignment.center,
            ),
          ),
          Container(width: 1, height: 34, color: p.border),
          Expanded(
            child: SfStatCell(
              value: '$alerts',
              label: 'Cảnh báo',
              valueColor: alerts > 0 ? SfColors.warning : null,
              align: CrossAxisAlignment.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Mốc trong ngày, màu theo loại sự kiện.
  List<SfTimelineEntry> _dayTimeline(Map<String, dynamic> safety) {
    final events = (safety['events'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (events.isEmpty) {
      return const [
        SfTimelineEntry(
          title: 'Bắt đầu ca lái',
          subtitle: 'Chưa có sự kiện an toàn nào được ghi nhận hôm nay',
          color: SfColors.green700,
        ),
      ];
    }

    return [
      for (final event in events)
        SfTimelineEntry(
          title: event['title']?.toString() ?? 'Sự kiện',
          time: event['time']?.toString(),
          subtitle: event['note']?.toString(),
          color: switch (event['type']?.toString()) {
            'ALERT' => SfColors.warning,
            'FLOOD' => SfColors.info,
            'INCIDENT' => SfColors.danger,
            _ => SfColors.green700,
          },
        ),
    ];
  }

  static int _int(Object? value, [int fallback = 0]) => switch (value) {
    final num number => number.round(),
    final String text => int.tryParse(text) ?? fallback,
    _ => fallback,
  };

  /// 214 → "3h34"
  static String _duration(int minutes) =>
      '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';

  static String _scoreLabel(int score) {
    if (score >= 80) return 'Một ngày ổn';
    if (score >= 65) return 'Ổn định';
    if (score >= 50) return 'Cần chú ý';
    return 'Rủi ro cao';
  }

  static String _scoreAdvice(int score) {
    if (score >= 80) {
      return 'Giữ nhịp lái như hiện tại. Mỗi cảnh báo nghiêm trọng '
          'trừ tới 12 điểm.';
    }
    if (score >= 65) return 'Vài cảnh báo gần đây đã trừ điểm.';
    if (score >= 50) return 'Nghỉ đúng lúc và hạn chế xao nhãng.';
    return 'Dưới 50 điểm bạn bị chuyển sang nhóm rủi ro cao. '
        'Liên hệ điều hành trước khi nhận chuyến tiếp theo.';
  }

  static String _advice(int score, int alerts) {
    if (alerts == 0) {
      return 'Hôm nay không có cảnh báo nào. Giữ lịch nghỉ 15 phút '
          'sau mỗi 3 giờ lái liên tục.';
    }
    return 'Cảnh báo buồn ngủ thường rơi vào đầu giờ chiều. '
        'Thử nghỉ ngắn 10 phút trước khung giờ đó thay vì đợi tới ngưỡng.';
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
