import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';
import 'document_image_screen.dart';
import 'document_review_screen.dart';
import 'driving_log_entry.dart';

class DrivingLogDetailScreen extends ConsumerStatefulWidget {
  const DrivingLogDetailScreen({required this.entryId, super.key});

  final String entryId;

  @override
  ConsumerState<DrivingLogDetailScreen> createState() =>
      _DrivingLogDetailScreenState();
}

class _DrivingLogDetailScreenState
    extends ConsumerState<DrivingLogDetailScreen> {
  late Future<DrivingLogEntry?> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(drivingLogRepositoryProvider).find(widget.entryId);
  }

  Future<void> _edit(DrivingLogEntry entry) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentReviewScreen(
          initialEntry: entry,
          serverOcrCompleted: entry.ocrText.contains('--- OCR server'),
        ),
      ),
    );
    if (saved == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.sf.bg,
    appBar: AppBar(title: const Text('Dữ liệu phiếu')),
    body: FutureBuilder<DrivingLogEntry?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final entry = snapshot.data;
        if (entry == null) {
          return const SfEmptyState(
            icon: Icons.description_outlined,
            title: 'Không tìm thấy phiếu',
            message: 'Bản ghi có thể đã bị xoá khỏi thiết bị.',
          );
        }
        return ListView(
          padding: SfSpace.screen,
          children: [
            _header(entry),
            const SizedBox(height: SfSpace.x20),
            const SfSectionLabel('Nhật trình dạng Excel'),
            const SizedBox(height: SfSpace.x8),
            _ExcelLikeTable(entry),
            const SizedBox(height: SfSpace.x20),
            _missingFields(entry),
            const SizedBox(height: SfSpace.x20),
            OutlinedButton.icon(
              onPressed: () => _edit(entry),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Sửa hoặc bổ sung dữ liệu'),
            ),
            const SizedBox(height: SfSpace.x12),
            FilledButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentImageScreen(entry: entry),
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Xem phiếu đã chụp'),
            ),
            const SizedBox(height: SfSpace.x24),
          ],
        );
      },
    ),
  );

  Widget _header(DrivingLogEntry entry) {
    final p = context.sf;
    final date = entry.voucherDate;
    final (color, label) = switch (entry.status) {
      DrivingLogStatus.verified => (SfColors.success, 'Đã kiểm tra'),
      DrivingLogStatus.exported => (p.accent, 'Đã xuất Excel'),
      DrivingLogStatus.draft => (SfColors.amber, 'Bản nháp'),
    };
    return SfCard(
      child: Row(
        children: [
          Container(
            width: SfTouch.min,
            height: SfTouch.min,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: SfRadius.controlR,
            ),
            child: Icon(Icons.description_outlined, color: color),
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.voucherNumber.isEmpty
                      ? 'Phiếu chưa có số'
                      : 'Phiếu số ${entry.voucherNumber}',
                  style: SfType.titleCard.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  date == null
                      ? 'Chưa xác định ngày'
                      : '${date.day}/${date.month}/${date.year} · ${entry.vehiclePlate}',
                  style: SfType.meta.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SfSpace.x8,
              vertical: SfSpace.x4,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: SfRadius.pillR,
            ),
            child: Text(label, style: SfType.label.copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  Widget _missingFields(DrivingLogEntry entry) {
    final missing = entry.missingFields;
    final complete = missing.isEmpty;
    final color = complete ? SfColors.success : SfColors.amber;
    return SfCard(
      emphasis: complete ? SfStatus.good : SfStatus.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete
                    ? Icons.task_alt_rounded
                    : Icons.pending_actions_outlined,
                color: color,
              ),
              const SizedBox(width: SfSpace.x8),
              Text(
                complete ? 'Dữ liệu đã đầy đủ' : 'Trường còn thiếu',
                style: SfType.titleCard.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x8),
          Text(
            complete
                ? 'Phiếu đã sẵn sàng để đưa vào báo cáo tháng.'
                : missing.map((field) => '• $field').join('\n'),
            style: SfType.body.copyWith(color: context.sf.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ExcelLikeTable extends StatelessWidget {
  const _ExcelLikeTable(this.entry);

  final DrivingLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final date = entry.voucherDate;
    final values = [
      date == null ? '' : '${date.day}/${date.month}',
      entry.assistantName.isEmpty
          ? entry.driverName
          : '${entry.driverName}\n(${entry.assistantName})',
      entry.projectAddress,
      entry.tripCount?.toString() ?? '',
      _money(entry.mealCost),
      _money(entry.ruleCost),
      _money(entry.tyreCost),
      _money(entry.otherCost),
      _money(entry.totalCost),
      entry.managerConfirmation,
    ];
    const headers = [
      'Ngày',
      'Tên lái xe\n(Phụ xe)',
      'Tên - địa chỉ công trình',
      'Số chuyến',
      'Ăn ca',
      'Luật',
      'Làm lốp',
      'Chi phí khác',
      'Tổng chi phí',
      'Xác nhận quản lý',
    ];
    return SfCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: SfRadius.cardR,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(128),
            border: TableBorder.all(color: p.border),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: p.accentTint),
                children: [
                  for (final header in headers)
                    Padding(
                      padding: const EdgeInsets.all(SfSpace.x8),
                      child: Text(
                        header,
                        textAlign: TextAlign.center,
                        style: SfType.label.copyWith(color: p.textPrimary),
                      ),
                    ),
                ],
              ),
              TableRow(
                children: [
                  for (final value in values)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 70),
                      child: Padding(
                        padding: const EdgeInsets.all(SfSpace.x8),
                        child: Text(
                          value.isEmpty ? '—' : value,
                          textAlign: TextAlign.center,
                          style: SfType.meta.copyWith(
                            color: value.isEmpty
                                ? SfColors.amber
                                : p.textPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _money(int? value) => value == null
      ? ''
      : value.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
}
