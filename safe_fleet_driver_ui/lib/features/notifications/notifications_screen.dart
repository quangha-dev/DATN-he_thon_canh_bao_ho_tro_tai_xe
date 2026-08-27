import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';

/// Thông báo — nhóm theo hôm nay / trước đó, viền thẻ theo mức ưu tiên.
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

  Future<void> _markRead(Map<String, dynamic> item) async {
    await ref
        .read(driverRepositoryProvider)
        .markNotificationRead((item['id'] as num).toInt());
    if (mounted) setState(_reload);
  }

  Future<void> _markAllRead(List<Map<String, dynamic>> items) async {
    final repository = ref.read(driverRepositoryProvider);
    for (final item in items.where((item) => item['read'] != true)) {
      await repository.markNotificationRead((item['id'] as num).toInt());
    }
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _future,
    builder: (context, snapshot) {
      final items = (snapshot.data ?? const <Map<String, dynamic>>[])
          .map(Map<String, dynamic>.from)
          .toList();
      final unread = items.where((item) => item['read'] != true).length;

      return SfSubScreen(
        title: 'Thông báo',
        subtitle: unread == 0 ? 'Đã đọc hết' : '$unread chưa đọc',
        trailing: unread == 0
            ? null
            : SfIconButton(
                icon: Icons.done_all_rounded,
                onHero: true,
                tooltip: 'Đọc hết',
                onTap: () => _markAllRead(items),
              ),
        scrollable: false,
        padding: EdgeInsets.zero,
        child: _body(snapshot, items),
      );
    },
  );

  Widget _body(
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
    List<Map<String, dynamic>> items,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return ListView(
        padding: SfSpace.screenSub,
        children: [
          SfSkeleton.card(lines: 2),
          const SizedBox(height: SfSpace.x12),
          SfSkeleton.card(lines: 2),
        ],
      );
    }
    if (snapshot.hasError) {
      return SfEmptyState(
        icon: Icons.notifications_off_rounded,
        title: 'Không tải được thông báo',
        message: '${snapshot.error}\nKiểm tra kết nối rồi mở lại.',
      );
    }
    if (items.isEmpty) {
      return const SfEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Không có thông báo mới',
        message: 'Chuyến mới, cảnh báo ngập và phản hồi SOS sẽ hiện ở đây.',
      );
    }

    final today = items.where(_isToday).toList();
    final earlier = items.where((item) => !_isToday(item)).toList();

    return ListView(
      padding: SfSpace.screenSub,
      children: [
        if (today.isNotEmpty) ...[
          const SfSectionLabel('Hôm nay'),
          const SizedBox(height: SfSpace.x10),
          for (final item in today) ...[
            _tile(item),
            const SizedBox(height: SfSpace.x10),
          ],
        ],
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: SfSpace.x8),
          const SfSectionLabel('Trước đó'),
          const SizedBox(height: SfSpace.x10),
          for (final item in earlier) ...[
            _tile(item),
            const SizedBox(height: SfSpace.x10),
          ],
        ],
      ],
    );
  }

  /// Thẻ đã đọc mờ đi (opacity .72) thay vì biến mất — tài xế vẫn tra lại được.
  Widget _tile(Map<String, dynamic> item) {
    final p = context.sf;
    final read = item['read'] == true;
    final type = item['type']?.toString();
    final status = _status(type);
    final ink = status.inkOf(p);

    final card = SfCard(
      emphasis: read ? null : status,
      borderWidth: read ? 1 : 1.5,
      padding: const EdgeInsets.all(SfSpace.x14),
      onTap: read ? null : () => _markRead(item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SfIconTile(
            icon: _icon(type),
            background: read ? p.surfaceAlt : status.tint(p),
            foreground: read ? p.textMuted : ink,
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item['title']?.toString() ?? 'Thông báo',
                        style: SfType.titleRow.copyWith(
                          color: p.textPrimary,
                          fontWeight: read
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!read) ...[
                      const SizedBox(width: SfSpace.x8),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: ink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item['content']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.caption.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: SfSpace.x8),
                Text(
                  _relativeTime(item['createdAt']),
                  style: SfType.chip.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return read ? Opacity(opacity: 0.72, child: card) : card;
  }

  static bool _isToday(Map<String, dynamic> item) {
    final created = DateTime.tryParse(item['createdAt']?.toString() ?? '');
    if (created == null) return true;
    final now = DateTime.now();
    return created.year == now.year &&
        created.month == now.month &&
        created.day == now.day;
  }

  /// "12 phút trước", "3 giờ trước", "27/07"
  static String _relativeTime(Object? value) {
    final created = DateTime.tryParse(value?.toString() ?? '');
    if (created == null) return '';
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${created.day.toString().padLeft(2, '0')}/'
        '${created.month.toString().padLeft(2, '0')}';
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
    'FLOOD' => Icons.water_drop_rounded,
    'AI_ALERT' => Icons.visibility_rounded,
    'GPS_LOST' => Icons.gps_off_rounded,
    'DRIVING_TIME' => Icons.timelapse_rounded,
    'TRIP_ASSIGNED' => Icons.route_rounded,
    'TRIP_DELAYED' => Icons.schedule_rounded,
    'MAINTENANCE' => Icons.build_rounded,
    _ => Icons.notifications_rounded,
  };
}
