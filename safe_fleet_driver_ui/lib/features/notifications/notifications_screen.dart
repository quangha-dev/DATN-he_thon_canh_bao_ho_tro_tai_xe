import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(driverRepositoryProvider).notifications();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: const Text('Thông báo')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              padding: const EdgeInsets.all(SfSpace.x16),
              children: [
                SfSkeleton.card(lines: 2),
                const SizedBox(height: SfSpace.x12),
                SfSkeleton.card(lines: 2),
              ],
            );
          }
          if (snapshot.hasError) {
            return SfEmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Không tải được thông báo',
              message: '${snapshot.error}\nKiểm tra kết nối rồi mở lại.',
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const SfEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Không có thông báo mới',
              message:
                  'Chuyến mới, cảnh báo ngập và phản hồi SOS sẽ hiện ở đây.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SfSpace.x16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: SfSpace.x12),
            itemBuilder: (context, index) =>
                _tile(p, Map<String, dynamic>.from(items[index])),
          );
        },
      ),
    );
  }

  Widget _tile(SfPalette p, Map<String, dynamic> item) {
    final read = item['read'] == true;
    final type = item['type']?.toString();
    final status = _status(type);
    final ink = status.inkOf(p);
    return SfCard(
      emphasis: read ? null : status,
      onTap: read
          ? null
          : () async {
              await ref
                  .read(driverRepositoryProvider)
                  .markNotificationRead((item['id'] as num).toInt());
              setState(_reload);
            },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: SfTouch.min,
            height: SfTouch.min,
            decoration: BoxDecoration(
              color: read ? p.surfaceAlt : status.tint(p),
              borderRadius: SfRadius.controlR,
            ),
            child: Icon(_icon(type), color: read ? p.textSecondary : ink),
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? 'Thông báo',
                  style: SfType.titleCard.copyWith(
                    color: p.textPrimary,
                    fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  item['content']?.toString() ?? '',
                  style: SfType.body.copyWith(color: p.textSecondary),
                ),
                if (!read) ...[
                  const SizedBox(height: SfSpace.x8),
                  Text(
                    'Chạm để đánh dấu đã đọc',
                    style: SfType.label.copyWith(color: p.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  SfStatus _status(String? type) => switch (type) {
    'SOS' => SfStatus.danger,
    'AI_ALERT' || 'FLOOD' || 'GPS_LOST' => SfStatus.warning,
    'TRIP_ASSIGNED' => SfStatus.good,
    'TRIP_DELAYED' || 'DRIVING_TIME' => SfStatus.pending,
    _ => SfStatus.pending,
  };

  IconData _icon(String? type) => switch (type) {
    'SOS' => Icons.sos_rounded,
    'FLOOD' => Icons.water_drop_outlined,
    'AI_ALERT' => Icons.visibility_outlined,
    'GPS_LOST' => Icons.gps_off_rounded,
    'DRIVING_TIME' => Icons.timelapse_rounded,
    'TRIP_ASSIGNED' => Icons.route_rounded,
    'TRIP_DELAYED' => Icons.schedule_rounded,
    'MAINTENANCE' => Icons.build_outlined,
    _ => Icons.notifications_none_rounded,
  };
}
