import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';
import '../driving/driving_mode_screen.dart';
import 'checklist_screen.dart';

Map<String, dynamic> tripDispatchInfo(Object? raw) {
  try {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) return const {};
    final data = Map<String, dynamic>.from(decoded);
    final dispatcher = data['dispatchedBy'];
    final dispatcherName = dispatcher is Map
        ? dispatcher['fullName']?.toString()
        : dispatcher?.toString();
    final document = data['warehouseDocument'] is Map
        ? Map<String, dynamic>.from(data['warehouseDocument'] as Map)
        : const <String, dynamic>{};
    final recipient = document['recipient'] is Map
        ? Map<String, dynamic>.from(document['recipient'] as Map)
        : const <String, dynamic>{};
    final preparedBy = document['preparedBy'] is Map
        ? Map<String, dynamic>.from(document['preparedBy'] as Map)
        : const <String, dynamic>{};
    final deliveryDriver = document['deliveryDriver'] is Map
        ? Map<String, dynamic>.from(document['deliveryDriver'] as Map)
        : const <String, dynamic>{};
    final items = (document['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return <String, dynamic>{
      if (data['cargoInfo']?.toString().trim().isNotEmpty == true)
        'cargoInfo': data['cargoInfo'].toString(),
      if (dispatcherName?.trim().isNotEmpty == true)
        'dispatchedBy': dispatcherName!,
      if (data['notes']?.toString().trim().isNotEmpty == true)
        'notes': data['notes'].toString(),
      if (document['issueNumber']?.toString().trim().isNotEmpty == true)
        'issueNumber': document['issueNumber'].toString(),
      if (document['issueDate']?.toString().trim().isNotEmpty == true)
        'issueDate': document['issueDate'].toString(),
      if (document['warehouseName']?.toString().trim().isNotEmpty == true)
        'warehouseName': document['warehouseName'].toString(),
      if (document['projectName']?.toString().trim().isNotEmpty == true)
        'projectName': document['projectName'].toString(),
      if (document['workItem']?.toString().trim().isNotEmpty == true)
        'workItem': document['workItem'].toString(),
      if (recipient['name']?.toString().trim().isNotEmpty == true)
        'recipientName': recipient['name'].toString(),
      if (recipient['phone']?.toString().trim().isNotEmpty == true)
        'recipientPhone': recipient['phone'].toString(),
      if (preparedBy['fullName']?.toString().trim().isNotEmpty == true)
        'preparedBy': preparedBy['fullName'].toString(),
      if (deliveryDriver['fullName']?.toString().trim().isNotEmpty == true)
        'deliveryDriver': deliveryDriver['fullName'].toString(),
      if (document['confirmationStatus'] != null)
        'confirmationStatus': document['confirmationStatus'].toString(),
      if (items.isNotEmpty) 'items': items,
    };
  } catch (_) {
    return const {};
  }
}

Map<String, dynamic> normalizedWarehouseIssueInfo(Object? raw) {
  if (raw is! Map) return const {};
  final document = Map<String, dynamic>.from(raw);
  final items = (document['items'] as List? ?? const []).whereType<Map>().map((
    rawItem,
  ) {
    final item = Map<String, dynamic>.from(rawItem);
    return <String, dynamic>{
      ...item,
      'quantityIssued': item['issuedQuantity'],
      'quantityReturned': item['returnedQuantity'],
      'confirmation': item['confirmationNote'] ?? item['conditionNote'],
    };
  }).toList();
  return <String, dynamic>{
    'issueNumber': document['issueNumber'],
    'issueDate': document['issueDate'],
    'warehouseName': document['warehouseName'],
    'projectName': document['projectName'],
    'workItem': document['workItem'],
    'recipientName': document['recipientName'],
    'recipientPhone': document['recipientPhone'],
    'preparedBy': document['preparedByName'],
    'deliveryDriver': document['deliveryPersonName'] ?? document['driverName'],
    'confirmationStatus': document['status'],
    'notes': document['notes'],
    if (items.isNotEmpty) 'items': items,
  }..removeWhere((_, value) => value == null || value.toString().isEmpty);
}

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({required this.tripId, super.key});

  final int tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(driverRepositoryProvider).trip(widget.tripId);
  }

  Future<void> _start(Map<String, dynamic> trip) async {
    final checklistPassed = await Navigator.push<bool>(
      context,
      SfSlideRoute<bool>(
        builder: (_) => ChecklistScreen(tripId: widget.tripId),
      ),
    );
    if (checklistPassed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(driverRepositoryProvider)
          .workflow(
            widget.tripId,
            'start',
            note: 'Bắt đầu từ Flutter Driver App',
          );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        SfDriveRoute<void>(builder: (_) => DrivingModeScreen(trip: trip)),
      );
      setState(() {
        _future = ref.read(driverRepositoryProvider).trip(widget.tripId);
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue(Map<String, dynamic> trip) async {
    await Navigator.push<void>(
      context,
      SfDriveRoute<void>(builder: (_) => DrivingModeScreen(trip: trip)),
    );
    if (!mounted) return;
    setState(() {
      _future = ref.read(driverRepositoryProvider).trip(widget.tripId);
    });
  }

  Future<void> _respondToAssignment({required bool accept}) async {
    if (!accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Từ chối chuyến này?'),
          content: const Text(
            'Điều phối sẽ thấy trạng thái từ chối và có thể giao chuyến cho tài xế khác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận từ chối'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(driverRepositoryProvider)
          .executeConfirmedTripAction(
            tripId: widget.tripId,
            action: accept ? 'accept' : 'reject',
            note: accept
                ? 'Tài xế nhận chuyến trên ứng dụng'
                : 'Tài xế từ chối chuyến trên ứng dụng',
          );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Đã nhận chuyến' : 'Đã từ chối chuyến'),
        ),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      final trip = snapshot.data ?? const <String, dynamic>{};
      final loading = snapshot.connectionState != ConnectionState.done;

      return SfSubScreen(
        title: loading
            ? 'Chi tiết chuyến'
            : trip['tripCode']?.toString() ?? 'Chuyến #${widget.tripId}',
        subtitle: loading
            ? null
            : trip['vehiclePlateNumber']?.toString() ?? 'Chưa gắn biển số',
        trailing: loading
            ? null
            : SfStatusPill.onHero(
                _statusLabel(
                  trip['status']?.toString().toUpperCase() ?? 'ASSIGNED',
                ),
              ),
        headerBottom: loading ? null : _headerStats(trip),
        bottomBar: loading || snapshot.hasError ? null : _actionBar(trip),
        child: loading
            ? Column(
                children: [
                  SfSkeleton.card(lines: 2),
                  const SizedBox(height: SfSpace.x12),
                  SfSkeleton.card(lines: 4),
                ],
              )
            : snapshot.hasError
            ? SfEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Không tải được chuyến',
                message:
                    '${snapshot.error}\n'
                    'Quay lại danh sách rồi mở lại chuyến này.',
              )
            : _body(trip),
      );
    },
  );

  /// Ba ô số trong header gradient: quãng đường, thời gian dự kiến, rủi ro.
  Widget _headerStats(Map<String, dynamic> trip) {
    final risk = trip['riskLevel']?.toString() ?? 'LOW';
    final distance = (trip['distanceKm'] as num?)?.toDouble();
    return Row(
      children: [
        Expanded(
          child: _headerStat(
            distance == null ? '--' : '${distance.toStringAsFixed(1)} km',
            'Quãng đường',
          ),
        ),
        Expanded(child: _headerStat(_plannedDuration(trip), 'Dự kiến')),
        Expanded(
          child: _headerStat(
            _riskLabel(risk),
            'Rủi ro',
            valueColor: _riskInkOnHero(risk),
          ),
        ),
      ],
    );
  }

  Widget _headerStat(String value, String label, {Color? valueColor}) =>
      SfStatCell(
        value: value,
        label: label,
        valueColor: valueColor ?? SfColors.onAccent,
        labelColor: SfColors.green300,
      );

  Widget _body(Map<String, dynamic> trip) {
    final status = trip['status']?.toString().toUpperCase() ?? 'ASSIGNED';
    final normalizedInfo = normalizedWarehouseIssueInfo(trip['warehouseIssue']);
    final dispatchInfo = normalizedInfo.isNotEmpty
        ? normalizedInfo
        : tripDispatchInfo(trip['plannedRoute']);
    final hero = Hero(
      tag: 'trip-${widget.tripId}',
      child: const Material(
        color: Colors.transparent,
        child: SizedBox.shrink(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        const SfSectionLabel('Lộ trình'),
        const SizedBox(height: SfSpace.x10),
        SfCard(child: SfTimeline(entries: _routeEntries(trip, status))),
        if (_checklistRemaining(trip) > 0 &&
            status != 'COMPLETED' &&
            status != 'CANCELLED' &&
            status != 'REJECTED') ...[
          const SizedBox(height: SfSpace.x14),
          SfCard(
            onTap: () => _openChecklist(trip),
            emphasis: SfStatus.warning,
            tinted: true,
            borderWidth: 1,
            padding: const EdgeInsets.all(SfSpace.x14),
            child: SfListRow(
              padding: EdgeInsets.zero,
              leading: const SfIconTile(
                icon: Icons.fact_check_rounded,
                size: 38,
                background: SfColors.warningBg,
                foreground: SfColors.warning,
              ),
              title: 'Checklist trước chuyến',
              subtitle: 'Còn ${_checklistRemaining(trip)} mục chưa xác nhận',
              titleColor: SfColors.warningInk,
              subtitleColor: SfColors.warning,
              showChevron: true,
            ),
          ),
        ],
        const SizedBox(height: SfSpace.x18),
        const SfSectionLabel('Hàng hoá & phương tiện'),
        const SizedBox(height: SfSpace.x10),
        _cargoGrid(trip),
        if (dispatchInfo.isNotEmpty) ...[
          const SizedBox(height: SfSpace.x18),
          const SfSectionLabel('Chứng từ điều phối'),
          const SizedBox(height: SfSpace.x10),
          _dispatchCard(dispatchInfo),
        ],
        if (status == 'COMPLETED' ||
            status == 'CANCELLED' ||
            status == 'REJECTED') ...[
          const SizedBox(height: SfSpace.x18),
          _TerminalTripNotice(
            icon: status == 'COMPLETED'
                ? Icons.task_alt_rounded
                : Icons.event_busy_rounded,
            title: status == 'COMPLETED'
                ? 'Chuyến đã hoàn thành'
                : status == 'REJECTED'
                ? 'Bạn đã từ chối chuyến'
                : 'Chuyến đã huỷ',
            message: status == 'COMPLETED'
                ? 'Hành trình đã lưu vào lịch sử hôm nay.'
                : status == 'REJECTED'
                ? 'Điều phối đã nhận được phản hồi và có thể giao chuyến khác.'
                : 'Chuyến bị huỷ không thể bắt đầu lại. '
                      'Liên hệ điều phối nếu cần chuyến thay thế.',
            status: status == 'COMPLETED' ? SfStatus.good : SfStatus.warning,
          ),
        ],
      ],
    );
  }

  /// Mốc lộ trình; điểm ngập trên tuyến chen vào giữa dưới dạng mốc đỏ.
  List<SfTimelineEntry> _routeEntries(
    Map<String, dynamic> trip,
    String status,
  ) {
    final started = status != 'ASSIGNED' && status != 'ACCEPTED';
    final floods = (trip['floodPointCount'] as num?)?.toInt() ?? 0;
    return [
      SfTimelineEntry(
        title: trip['startLocation']?.toString() ?? '--',
        time: _time(trip['plannedStartTime']),
        subtitle: started ? 'đã rời kho' : 'chưa xuất phát',
        color: SfColors.green700,
      ),
      if (floods > 0)
        SfTimelineEntry(
          title: 'Cảnh báo: $floods điểm ngập trên tuyến',
          subtitle: 'Trợ lý sẽ gợi ý đường vòng khi tới gần',
          color: SfColors.danger,
          icon: Icons.water_drop_rounded,
        ),
      SfTimelineEntry(
        title: trip['endLocation']?.toString() ?? '--',
        time: 'Dự kiến ${_time(trip['estimatedEndTime'])}',
        subtitle: trip['contactName']?.toString(),
        color: SfColors.green700,
        isSquare: true,
      ),
    ];
  }

  /// Grid 2×2: biển số, loại hàng, khối lượng, số phiếu.
  Widget _cargoGrid(Map<String, dynamic> trip) {
    final p = context.sf;
    final cells = <(String, String)>[
      ('Biển số', trip['vehiclePlateNumber']?.toString() ?? '--'),
      ('Loại hàng', trip['cargoType']?.toString() ?? '--'),
      (
        'Khối lượng',
        trip['cargoWeightTon'] == null ? '--' : '${trip['cargoWeightTon']} tấn',
      ),
      ('Số phiếu', '${(trip['documentCount'] as num?)?.toInt() ?? 0} phiếu'),
    ];
    return SfCard(
      child: Column(
        children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: SfSpace.x16),
            Row(
              children: [
                for (var col = 0; col < 2; col++)
                  Expanded(
                    child: SfStatCell(
                      value: cells[row * 2 + col].$2,
                      label: cells[row * 2 + col].$1,
                      valueStyle: SfType.titleCardSm,
                      labelColor: p.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  int _checklistRemaining(Map<String, dynamic> trip) {
    if (trip['checklistCompleted'] == true) return 0;
    final remaining = (trip['checklistRemaining'] as num?)?.toInt();
    return remaining ?? 0;
  }

  void _openChecklist(Map<String, dynamic> trip) => Navigator.push<bool>(
    context,
    SfSlideRoute<bool>(builder: (_) => ChecklistScreen(tripId: widget.tripId)),
  ).then((_) => setState(_reload));

  /// "2h00" — khoảng cách giữa giờ khởi hành và giờ đến dự kiến.
  String _plannedDuration(Map<String, dynamic> trip) {
    final start = DateTime.tryParse(trip['plannedStartTime']?.toString() ?? '');
    final end = DateTime.tryParse(trip['estimatedEndTime']?.toString() ?? '');
    if (start == null || end == null || !end.isAfter(start)) return '--';
    final minutes = end.difference(start).inMinutes;
    return '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';
  }

  Color _riskInkOnHero(String risk) => switch (risk.toUpperCase()) {
    'CRITICAL' || 'HIGH' => SfColors.amber,
    'MEDIUM' => SfColors.green300,
    _ => SfColors.onAccent,
  };

  // ---- Thanh hành động dính đáy ----

  Widget _actionBar(Map<String, dynamic> trip) {
    final status = trip['status']?.toString().toUpperCase() ?? 'ASSIGNED';
    if (status == 'COMPLETED' ||
        status == 'CANCELLED' ||
        status == 'REJECTED') {
      return const SizedBox.shrink();
    }
    if (status == 'ASSIGNED') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _respondToAssignment(accept: false),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Từ chối'),
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: SfPrimaryAction(
              label: _busy ? 'Đang xử lý' : 'Nhận chuyến',
              icon: Icons.check_rounded,
              busy: _busy,
              onPressed: () => _respondToAssignment(accept: true),
            ),
          ),
        ],
      );
    }
    final running = status == 'IN_PROGRESS' || status == 'RESTING';
    final phone = trip['contactPhone']?.toString();

    return Row(
      children: [
        SfIconButton(
          icon: Icons.call_rounded,
          size: SfTouch.primaryHeight,
          tooltip: phone == null || phone.isEmpty
              ? 'Chưa có số liên hệ'
              : 'Gọi $phone',
          onTap: phone == null || phone.isEmpty ? null : () {},
        ),
        const SizedBox(width: SfSpace.x12),
        Expanded(
          child: SfPrimaryAction(
            label: running
                ? 'Vào chế độ lái'
                : _busy
                ? 'Đang bắt đầu chuyến'
                : 'Kiểm tra xe và khởi hành',
            icon: running ? Icons.navigation_rounded : Icons.fact_check_rounded,
            busy: _busy,
            onPressed: running ? () => _continue(trip) : () => _start(trip),
          ),
        ),
      ],
    );
  }

  // ---- Chứng từ ----

  Widget _dispatchCard(Map<String, dynamic> info) {
    final p = context.sf;
    return SfCard(
      emphasis: SfStatus.pending,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: SfColors.info),
              const SizedBox(width: SfSpace.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info['issueNumber'] == null
                          ? 'Thông tin điều phối'
                          : 'Phiếu xuất kho ${info['issueNumber']}',
                      style: SfType.titleCard.copyWith(color: p.textPrimary),
                    ),
                    if (info['issueDate'] != null)
                      Text(
                        'Ngày xuất ${info['issueDate']}',
                        style: SfType.meta.copyWith(color: p.textSecondary),
                      ),
                  ],
                ),
              ),
              if (info['confirmationStatus'] != null)
                const SfStatusPill(
                  'Chờ nhận',
                  status: SfStatus.pending,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: SfSpace.x16),
          if (info['warehouseName'] case final value?)
            _row('Kho xuất', value.toString()),
          if (info['projectName'] case final value?)
            _row('Công trình', value.toString()),
          if (info['workItem'] case final value?)
            _row('Hạng mục', value.toString()),
          if (info['recipientName'] case final value?)
            _row('Người nhận', value.toString()),
          if (info['recipientPhone'] case final value?)
            _row('Điện thoại', value.toString()),
          if (info['items'] case final List items) _goodsList(items),
          if (info['items'] == null && info['cargoInfo'] != null)
            _row('Hàng hoá', info['cargoInfo'].toString()),
          const Divider(height: SfSpace.x24),
          if (info['preparedBy'] case final value?)
            _row('Người lập phiếu', value.toString()),
          if (info['deliveryDriver'] case final value?)
            _row('Người giao hàng', value.toString()),
          if (info['preparedBy'] == null && info['dispatchedBy'] != null)
            _row('Người điều phối', info['dispatchedBy'].toString()),
          if (info['notes'] case final notes?)
            _row('Ghi chú', notes, isLast: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool isLast = false}) {
    final p = context.sf;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : SfSpace.x12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: SfType.meta.copyWith(color: p.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: SfType.body.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goodsList(List<dynamic> rawItems) {
    final p = context.sf;
    final items = rawItems.whereType<Map>().toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: SfSpace.x8),
          child: SfSectionLabel('Danh sách hàng hoá'),
        ),
        ...items.indexed.map((entry) {
          final item = Map<String, dynamic>.from(entry.$2);
          final issued = _quantity(item['quantityIssued']);
          final returned = _quantity(item['quantityReturned']);
          final unit = item['unit']?.toString() ?? '';
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: SfSpace.x8),
            padding: const EdgeInsets.all(SfSpace.x12),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: SfRadius.controlR,
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: SfColors.info,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${entry.$1 + 1}',
                        style: SfType.label.copyWith(color: SfColors.onAccent),
                      ),
                    ),
                    const SizedBox(width: SfSpace.x8),
                    Expanded(
                      child: Text(
                        item['description']?.toString() ?? '--',
                        style: SfType.titleCard.copyWith(color: p.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SfSpace.x8),
                Wrap(
                  spacing: SfSpace.x16,
                  runSpacing: SfSpace.x4,
                  children: [
                    Text(
                      'Mã ${item['itemCode']?.toString().trim().isNotEmpty == true ? item['itemCode'] : '--'}',
                      style: SfType.mono.copyWith(color: p.textSecondary),
                    ),
                    Text(
                      'Xuất $issued $unit',
                      style: SfType.mono.copyWith(color: p.textPrimary),
                    ),
                    if (returned != '0')
                      Text(
                        'Trả $returned $unit',
                        style: SfType.mono.copyWith(color: p.textSecondary),
                      ),
                  ],
                ),
                if (item['confirmation']?.toString().trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: SfSpace.x8),
                    child: Text(
                      'Lưu ý: ${item['confirmation']}',
                      style: SfType.meta.copyWith(color: p.textSecondary),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _quantity(Object? value) {
    final number = num.tryParse(value?.toString() ?? '') ?? 0;
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(2);
  }

  String _time(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '--:--';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _riskLabel(String value) => switch (value.toUpperCase()) {
    'CRITICAL' => 'Rất cao',
    'HIGH' => 'Cao',
    'MEDIUM' => 'Vừa',
    _ => 'Thấp',
  };

  String _statusLabel(String status) => switch (status) {
    'DRAFT' => 'Chờ giao',
    'ASSIGNED' => 'Đã giao',
    'ACCEPTED' => 'Đã nhận',
    'IN_PROGRESS' => 'Đang chạy',
    'RESTING' => 'Đang nghỉ',
    'COMPLETED' => 'Hoàn thành',
    'DELAYED' => 'Trễ giờ',
    'INCIDENT' => 'Có sự cố',
    'REJECTED' => 'Đã từ chối',
    'CANCELLED' => 'Đã huỷ',
    _ => status,
  };
}

class _TerminalTripNotice extends StatelessWidget {
  const _TerminalTripNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String message;
  final SfStatus status;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final ink = status.inkOf(p);
    return SfCard(
      emphasis: status,
      child: Row(
        children: [
          Icon(icon, color: ink),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SfType.titleCard.copyWith(color: ink)),
                const SizedBox(height: SfSpace.x4),
                Text(
                  message,
                  style: SfType.meta.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
