import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

import '../../app.dart';
import '../../core/ai/cabin_safety_provider.dart';
import '../../core/widgets/ui.dart';
import 'document_ocr_queue_repository.dart';
import 'document_ocr_sync_queue.dart';
import 'document_review_screen.dart';
import 'driving_log_detail_screen.dart';
import 'driving_log_entry.dart';

class DrivingLogListScreen extends ConsumerStatefulWidget {
  const DrivingLogListScreen({super.key});

  @override
  ConsumerState<DrivingLogListScreen> createState() =>
      _DrivingLogListScreenState();
}

class _DrivingLogListScreenState extends ConsumerState<DrivingLogListScreen> {
  final _picker = ImagePicker();
  final List<_ScanQueueItem> _scanQueue = [];
  final List<DocumentOcrQueueItem> _serverQueue = [];
  late final DocumentOcrSyncQueue _ocrSyncQueue;
  StreamSubscription<List<DocumentOcrQueueItem>>? _ocrQueueSubscription;
  late DateTime _month;
  late Future<List<DrivingLogEntry>> _future;
  var _drainingQueue = false;
  var _exporting = false;
  var _queueSequence = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _reload();
    _ocrSyncQueue = ref.read(documentOcrSyncQueueProvider);
    _ocrQueueSubscription = _ocrSyncQueue.changes.listen(_updateServerQueue);
    unawaited(_loadServerQueue());
  }

  Future<void> _loadServerQueue() async {
    _updateServerQueue(await _ocrSyncQueue.list());
  }

  void _updateServerQueue(List<DocumentOcrQueueItem> items) {
    if (!mounted) return;
    setState(() {
      _serverQueue
        ..clear()
        ..addAll(items);
      _reload();
    });
  }

  @override
  void dispose() {
    unawaited(_ocrQueueSubscription?.cancel());
    super.dispose();
  }

  void _reload() {
    _future = ref.read(drivingLogRepositoryProvider).list(month: _month);
  }

  void _changeMonth(int offset) {
    final next = DateTime(_month.year, _month.month + offset);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _month = next;
      _reload();
    });
  }

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<_ScanSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SfSpace.x16,
            0,
            SfSpace.x16,
            SfSpace.x16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Chụp phiếu mới'),
                subtitle: const Text('Dùng camera sau và tự động crop phiếu'),
                onTap: () => Navigator.pop(context, _ScanSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Chọn ảnh có sẵn'),
                subtitle: const Text('Có thể chọn nhiều ảnh trong một lần'),
                onTap: () => Navigator.pop(context, _ScanSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    try {
      await _pickAndEnqueue(source);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh phiếu: $error')),
      );
    }
  }

  Future<void> _pickAndEnqueue(_ScanSource source) async {
    final cabinController = ref.read(cabinSafetyProvider.notifier);
    final cabinWasEnabled = ref.read(cabinSafetyProvider).enabled;
    if (cabinWasEnabled) {
      await cabinController.stop();
    }
    var images = <XFile>[];
    try {
      if (source == _ScanSource.camera) {
        final image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 96,
          preferredCameraDevice: CameraDevice.rear,
        );
        if (image != null) images = [image];
      } else {
        images = await _picker.pickMultiImage(imageQuality: 96);
      }
    } finally {
      if (cabinWasEnabled) {
        await cabinController.start();
      }
    }
    if (images.isEmpty || !mounted) return;

    setState(() {
      _scanQueue.addAll(
        images.map(
          (image) => _ScanQueueItem(id: ++_queueSequence, image: image),
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          images.length == 1
              ? 'Đã thêm 1 ảnh vào danh sách chờ.'
              : 'Đã thêm ${images.length} ảnh vào danh sách chờ.',
        ),
      ),
    );
    unawaited(_drainScanQueue());
  }

  Future<void> _drainScanQueue() async {
    if (_drainingQueue) return;
    _drainingQueue = true;
    // Giữ tham chiếu service từ đầu để phiếu hiện tại vẫn được lưu nếu người
    // dùng rời màn hình trong lúc OCR đang chạy.
    final driverRepository = ref.read(driverRepositoryProvider);
    final scanService = ref.read(documentScanServiceProvider);
    final logRepository = ref.read(drivingLogRepositoryProvider);
    final ocrSyncQueue = ref.read(documentOcrSyncQueueProvider);
    var driverName = '';
    var plate = '';
    try {
      final bootstrap = await driverRepository.bootstrap();
      final driver = bootstrap.driver;
      driverName =
          driver?['fullName']?.toString() ??
          bootstrap.profile['fullName']?.toString() ??
          '';
      plate =
          driver?['currentVehiclePlateNumber']?.toString() ??
          bootstrap.currentTrip?['vehiclePlateNumber']?.toString() ??
          '';
    } catch (_) {
      // OCR vẫn chạy offline và người dùng có thể bổ sung khi mở phiếu.
    }

    try {
      while (true) {
        final waiting = _scanQueue
            .where((item) => item.status == _ScanQueueStatus.waiting)
            .firstOrNull;
        if (waiting == null) break;
        _updateQueueItem(waiting.id, status: _ScanQueueStatus.processing);
        try {
          final draft = await scanService.createPendingServerDraft(
            sourcePath: waiting.image.path,
            driverName: driverName,
            vehiclePlate: plate,
          );
          await logRepository.save(draft);
          await ocrSyncQueue.enqueue(draft);
          void removeCompletedItem() {
            _scanQueue.removeWhere((item) => item.id == waiting.id);
            if (mounted) _reload();
          }

          if (mounted) {
            setState(removeCompletedItem);
          } else {
            removeCompletedItem();
            continue;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${path.basename(waiting.image.path)} đã sẵn sàng để nhập bổ sung.',
              ),
              action: SnackBarAction(
                label: 'Nhập ngay',
                onPressed: () => _editPendingEntry(draft.id),
              ),
            ),
          );
        } catch (error) {
          _updateQueueItem(
            waiting.id,
            status: _ScanQueueStatus.failed,
            error: error.toString(),
          );
        }
      }
    } finally {
      _drainingQueue = false;
      if (_scanQueue.any((item) => item.status == _ScanQueueStatus.waiting)) {
        unawaited(_drainScanQueue());
      }
    }
  }

  void _updateQueueItem(
    int id, {
    required _ScanQueueStatus status,
    String? error,
  }) {
    final index = _scanQueue.indexWhere((item) => item.id == id);
    if (index < 0) return;
    void updateItem() {
      _scanQueue[index] = _scanQueue[index].copyWith(
        status: status,
        error: error,
      );
    }

    if (mounted) {
      setState(updateItem);
    } else {
      updateItem();
    }
  }

  void _retryQueueItem(int id) {
    _updateQueueItem(id, status: _ScanQueueStatus.waiting, error: '');
    unawaited(_drainScanQueue());
  }

  Future<void> _openEntry(String id) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => DrivingLogDetailScreen(entryId: id)),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _supplementProcessedEntry(String id) async {
    final entry = await ref.read(drivingLogRepositoryProvider).find(id);
    if (entry == null || !mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DocumentReviewScreen(initialEntry: entry, serverOcrCompleted: true),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _deleteEntry(
    DrivingLogEntry entry, {
    required bool pendingOcr,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá phiếu này?'),
        content: Text(
          pendingOcr
              ? 'Phiếu sẽ bị xoá khỏi danh sách chờ và kết quả OCR đến sau sẽ bị bỏ qua. Thao tác này không thể hoàn tác.'
              : 'Bản ghi và ảnh phiếu trên điện thoại sẽ bị xoá. Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: SfColors.danger),
            child: const Text('Xoá phiếu'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (pendingOcr) await _ocrSyncQueue.cancel(entry.id);
    await ref.read(drivingLogRepositoryProvider).delete(entry.id);
    for (final imagePath in {
      entry.imagePath,
      entry.originalImagePath,
    }.where((value) => value.trim().isNotEmpty)) {
      try {
        final image = File(imagePath);
        if (await image.exists()) await image.delete();
      } catch (_) {
        // Bản ghi đã bị xoá; ảnh tạm không được phép làm thao tác thất bại.
      }
    }
    if (!mounted) return;
    await _loadServerQueue();
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã xoá phiếu.')));
  }

  Future<void> _editPendingEntry(String id) async {
    final entry = await ref.read(drivingLogRepositoryProvider).find(id);
    if (entry == null || !mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentReviewScreen(
          initialEntry: entry,
          serverOcrManagedByQueue: true,
        ),
      ),
    );
    if (!mounted) return;
    final currentQueue = await _ocrSyncQueue.list();
    if (!mounted) return;
    _updateServerQueue(currentQueue);
    if (saved == true) {
      final stillProcessing = currentQueue.any((item) => item.entryId == id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stillProcessing
                ? 'Đã lưu thông tin bổ sung. OCR máy tính vẫn tiếp tục xử lý.'
                : 'Đã lưu thông tin. OCR máy tính đã hoàn thành.',
          ),
        ),
      );
    }
  }

  Future<void> _export(List<DrivingLogEntry> entries) async {
    final ready = entries.where((entry) => entry.hasRequiredOperationalFields);
    if (ready.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có phiếu đủ dữ liệu để xuất Excel.'),
        ),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final values = ready.toList();
      final file = await ref
          .read(drivingLogExportServiceProvider)
          .export(month: _month, entries: values);
      await ref
          .read(drivingLogRepositoryProvider)
          .markExported(values.map((entry) => entry.id));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          title: 'Nhật trình lái xe tháng ${_month.month}/${_month.year}',
          text: 'File nhật trình được tạo offline từ các phiếu đã kiểm tra.',
        ),
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không xuất được file Excel: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Nhật trình & phiếu'),
        actions: [
          IconButton(
            onPressed: _chooseSource,
            tooltip: 'Quét phiếu',
            icon: const Icon(Icons.document_scanner_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _chooseSource,
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Quét phiếu'),
      ),
      body: Stack(
        children: [
          FutureBuilder<List<DrivingLogEntry>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData && !snapshot.hasError) {
                return ListView(
                  padding: SfSpace.screen,
                  children: [
                    const SfSkeleton(height: 68),
                    const SizedBox(height: SfSpace.x16),
                    SfSkeleton.card(lines: 4),
                  ],
                );
              }
              if (snapshot.hasError) {
                return SfEmptyState(
                  icon: Icons.storage_outlined,
                  title: 'Không đọc được dữ liệu trên máy',
                  message: snapshot.error.toString(),
                  action: TextButton(
                    onPressed: () => setState(_reload),
                    child: const Text('Thử lại'),
                  ),
                );
              }
              final entries = snapshot.requireData;
              final queuedEntryIds = _serverQueue
                  .map((item) => item.entryId)
                  .toSet();
              final orphanPendingEntries = entries
                  .where(
                    (entry) =>
                        entry.isComputerOcrPending &&
                        !queuedEntryIds.contains(entry.id),
                  )
                  .toList();
              final processedEntries = entries
                  .where(
                    (entry) =>
                        !queuedEntryIds.contains(entry.id) &&
                        !entry.isComputerOcrPending,
                  )
                  .toList();
              final needsSupplementEntries = processedEntries
                  .where((entry) => entry.missingFields.isNotEmpty)
                  .toList();
              final completedEntries = processedEntries
                  .where((entry) => entry.missingFields.isEmpty)
                  .toList();
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_reload);
                  await _future;
                  await _ocrSyncQueue.syncNow();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    SfSpace.x16,
                    SfSpace.x8,
                    SfSpace.x16,
                    112,
                  ),
                  children: [
                    _monthSelector(),
                    const SizedBox(height: SfSpace.x16),
                    _summary(processedEntries),
                    const SizedBox(height: SfSpace.x20),
                    if (_scanQueue.isNotEmpty ||
                        _serverQueue.isNotEmpty ||
                        orphanPendingEntries.isNotEmpty) ...[
                      SfSectionLabel(
                        'Đang gửi & xử lý OCR',
                        trailing: Text(
                          '${_scanQueue.length + _serverQueue.length + orphanPendingEntries.length} ảnh',
                          style: SfType.meta.copyWith(color: p.textSecondary),
                        ),
                      ),
                      const SizedBox(height: SfSpace.x8),
                      for (final item in _scanQueue) ...[
                        _ScanQueueCard(
                          item: item,
                          onRetry: item.status == _ScanQueueStatus.failed
                              ? () => _retryQueueItem(item.id)
                              : null,
                          onRemove:
                              item.status == _ScanQueueStatus.failed ||
                                  item.status == _ScanQueueStatus.waiting
                              ? () => setState(
                                  () => _scanQueue.removeWhere(
                                    (queued) => queued.id == item.id,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: SfSpace.x8),
                      ],
                      for (final item in _serverQueue) ...[
                        _ServerOcrQueueCard(
                          item: item,
                          entry: entries
                              .where((entry) => entry.id == item.entryId)
                              .firstOrNull,
                          onTap: () => _editPendingEntry(item.entryId),
                          onRetry: item.status == DocumentOcrQueueStatus.failed
                              ? () => _ocrSyncQueue.retry(item.entryId)
                              : null,
                          onDelete: () {
                            final entry = entries
                                .where((entry) => entry.id == item.entryId)
                                .firstOrNull;
                            if (entry != null) {
                              _deleteEntry(entry, pendingOcr: true);
                            }
                          },
                        ),
                        const SizedBox(height: SfSpace.x8),
                      ],
                      for (final entry in orphanPendingEntries) ...[
                        _ServerOcrQueueCard(
                          item: DocumentOcrQueueItem(
                            entryId: entry.id,
                            imagePath: entry.originalImagePath.isNotEmpty
                                ? entry.originalImagePath
                                : entry.imagePath,
                            serverJobId: null,
                            status: DocumentOcrQueueStatus.pendingUpload,
                            attempts: 0,
                            lastError: null,
                            createdAt: entry.createdAt,
                            updatedAt: entry.updatedAt,
                          ),
                          entry: entry,
                          onTap: () => _editPendingEntry(entry.id),
                          onRetry: () async {
                            await _ocrSyncQueue.recoverMissingEntries();
                            await _ocrSyncQueue.syncNow();
                          },
                          onDelete: () => _deleteEntry(entry, pendingOcr: true),
                        ),
                        const SizedBox(height: SfSpace.x8),
                      ],
                      const SizedBox(height: SfSpace.x12),
                    ],
                    if (needsSupplementEntries.isNotEmpty) ...[
                      SfSectionLabel(
                        'OCR đã xong · cần bổ sung',
                        trailing: Text(
                          '${needsSupplementEntries.length} phiếu',
                          style: SfType.meta.copyWith(color: SfColors.amber),
                        ),
                      ),
                      const SizedBox(height: SfSpace.x8),
                      for (final entry in needsSupplementEntries) ...[
                        _EntryCard(
                          entry: entry,
                          onTap: () => _supplementProcessedEntry(entry.id),
                          onDelete: () =>
                              _deleteEntry(entry, pendingOcr: false),
                        ),
                        const SizedBox(height: SfSpace.x8),
                      ],
                      const SizedBox(height: SfSpace.x12),
                    ],
                    SfSectionLabel(
                      'Phiếu hoàn chỉnh',
                      trailing: TextButton.icon(
                        onPressed: completedEntries.isEmpty || _exporting
                            ? null
                            : () => _export(completedEntries),
                        icon: const Icon(Icons.table_view_outlined, size: 18),
                        label: const Text('Xuất Excel'),
                      ),
                    ),
                    const SizedBox(height: SfSpace.x8),
                    if (completedEntries.isEmpty)
                      SfCard(
                        child: Column(
                          children: [
                            Icon(
                              Icons.document_scanner_outlined,
                              size: 42,
                              color: p.textMuted,
                            ),
                            const SizedBox(height: SfSpace.x12),
                            Text(
                              needsSupplementEntries.isNotEmpty
                                  ? 'Chưa có phiếu hoàn chỉnh'
                                  : 'Chưa có phiếu trong tháng này',
                              style: SfType.titleCard.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                            const SizedBox(height: SfSpace.x4),
                            Text(
                              _serverQueue.isNotEmpty
                                  ? 'Phiếu đang được gửi lên máy tính để nhận dạng.'
                                  : needsSupplementEntries.isNotEmpty
                                  ? 'Bổ sung các trường còn thiếu để hoàn tất phiếu.'
                                  : 'Quét phiếu để OCR trên máy tính và lưu nhật trình.',
                              textAlign: TextAlign.center,
                              style: SfType.meta.copyWith(
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final entry in completedEntries) ...[
                        _EntryCard(
                          entry: entry,
                          onTap: () => _openEntry(entry.id),
                          onDelete: () =>
                              _deleteEntry(entry, pendingOcr: false),
                        ),
                        const SizedBox(height: SfSpace.x8),
                      ],
                  ],
                ),
              );
            },
          ),
          if (_exporting)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _monthSelector() {
    final now = DateTime.now();
    final current = _month.year == now.year && _month.month == now.month;
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            'Tháng ${_month.month} · ${_month.year}',
            textAlign: TextAlign.center,
            style: SfType.titleCard.copyWith(color: context.sf.textPrimary),
          ),
        ),
        IconButton.filledTonal(
          onPressed: current ? null : () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _summary(List<DrivingLogEntry> entries) {
    final drafts = entries
        .where((entry) => entry.missingFields.isNotEmpty)
        .length;
    final trips = entries.fold<int>(
      0,
      (total, entry) => total + (entry.tripCount ?? 0),
    );
    return SfCard(
      child: Row(
        children: [
          _summaryValue('${entries.length}', 'phiếu'),
          _summaryValue('$trips', 'chuyến'),
          _summaryValue('$drafts', 'cần bổ sung', warn: drafts > 0),
        ],
      ),
    );
  }

  Widget _summaryValue(String value, String label, {bool warn = false}) =>
      Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: SfType.titleScreen.copyWith(
                color: warn ? SfColors.amber : context.sf.textPrimary,
              ),
            ),
            Text(
              label,
              style: SfType.meta.copyWith(color: context.sf.textSecondary),
            ),
          ],
        ),
      );
}

enum _ScanSource { camera, gallery }

enum _ScanQueueStatus { waiting, processing, failed }

class _ScanQueueItem {
  const _ScanQueueItem({
    required this.id,
    required this.image,
    this.status = _ScanQueueStatus.waiting,
    this.error,
  });

  final int id;
  final XFile image;
  final _ScanQueueStatus status;
  final String? error;

  _ScanQueueItem copyWith({_ScanQueueStatus? status, String? error}) =>
      _ScanQueueItem(
        id: id,
        image: image,
        status: status ?? this.status,
        error: error == '' ? null : (error ?? this.error),
      );
}

class _ScanQueueCard extends StatelessWidget {
  const _ScanQueueCard({
    required this.item,
    required this.onRetry,
    required this.onRemove,
  });

  final _ScanQueueItem item;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final failed = item.status == _ScanQueueStatus.failed;
    final processing = item.status == _ScanQueueStatus.processing;
    final color = failed
        ? SfColors.danger
        : processing
        ? SfColors.teal
        : p.textMuted;
    final label = failed
        ? 'Xử lý thất bại'
        : processing
        ? 'Đang lưu ảnh và tạo bản ghi...'
        : 'Đang chờ tạo bản ghi';

    return SfCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: SfRadius.controlR,
            child: Image.file(
              File(item.image.path),
              width: SfTouch.min,
              height: SfTouch.min,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: SfTouch.min,
                height: SfTouch.min,
                color: p.surfaceAlt,
                child: Icon(Icons.image_not_supported_outlined, color: color),
              ),
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  path.basename(item.image.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.titleCard.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: SfSpace.x4),
                Row(
                  children: [
                    if (processing)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    else
                      Icon(
                        failed
                            ? Icons.error_outline_rounded
                            : Icons.schedule_rounded,
                        size: 16,
                        color: color,
                      ),
                    const SizedBox(width: SfSpace.x4),
                    Expanded(
                      child: Text(
                        label,
                        style: SfType.meta.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
                if (failed && item.error != null) ...[
                  const SizedBox(height: SfSpace.x4),
                  Text(
                    item.error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SfType.meta.copyWith(color: p.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (onRetry != null)
            IconButton(
              onPressed: onRetry,
              tooltip: 'Thử lại',
              icon: const Icon(Icons.refresh_rounded),
            ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: 'Bỏ khỏi danh sách',
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}

class _ServerOcrQueueCard extends StatelessWidget {
  const _ServerOcrQueueCard({
    required this.item,
    required this.entry,
    required this.onTap,
    required this.onRetry,
    required this.onDelete,
  });

  final DocumentOcrQueueItem item;
  final DrivingLogEntry? entry;
  final VoidCallback onTap;
  final VoidCallback? onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final (label, color, icon) = switch (item.status) {
      DocumentOcrQueueStatus.pendingUpload => (
        item.lastError == null
            ? 'Đã lưu · chờ kết nối để gửi'
            : 'Mất kết nối · sẽ tự gửi lại',
        SfColors.amber,
        Icons.cloud_upload_outlined,
      ),
      DocumentOcrQueueStatus.uploading => (
        'Đang gửi ảnh lên máy tính...',
        p.accent,
        Icons.upload_rounded,
      ),
      DocumentOcrQueueStatus.waitingResult => (
        item.lastError == null
            ? 'Máy tính đang xử lý OCR...'
            : 'Chờ mạng để nhận kết quả từ máy tính',
        SfColors.teal,
        Icons.memory_rounded,
      ),
      DocumentOcrQueueStatus.waitingReview => (
        'Chờ quản lý xác nhận biển số',
        SfColors.amber,
        Icons.fact_check_outlined,
      ),
      DocumentOcrQueueStatus.failed => (
        'OCR máy tính chưa thành công',
        SfColors.danger,
        Icons.error_outline_rounded,
      ),
    };
    final active =
        item.status == DocumentOcrQueueStatus.uploading ||
        (item.status == DocumentOcrQueueStatus.waitingResult &&
            item.lastError == null);

    final voucherNumber = entry?.voucherNumber.trim() ?? '';
    final project = entry?.projectAddress.trim() ?? '';
    final title = voucherNumber.isNotEmpty
        ? 'Phiếu số $voucherNumber'
        : project.isNotEmpty
        ? project
        : 'Phiếu đang chờ OCR';

    return SfCard(
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: SfRadius.controlR,
            child: Image.file(
              File(item.imagePath),
              width: SfTouch.min,
              height: SfTouch.min,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: SfTouch.min,
                height: SfTouch.min,
                color: p.surfaceAlt,
                child: Icon(Icons.description_outlined, color: color),
              ),
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.titleCard.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: SfSpace.x4),
                Row(
                  children: [
                    if (active)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    else
                      Icon(icon, size: 16, color: color),
                    const SizedBox(width: SfSpace.x4),
                    Expanded(
                      child: Text(
                        label,
                        style: SfType.meta.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
                if (item.lastError != null) ...[
                  const SizedBox(height: SfSpace.x4),
                  Text(
                    item.lastError!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SfType.meta.copyWith(color: p.textSecondary),
                  ),
                ],
                const SizedBox(height: SfSpace.x4),
                Text(
                  'Chạm để nhập hoặc sửa thông tin bổ sung',
                  style: SfType.meta.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          if (onRetry != null)
            IconButton(
              onPressed: onRetry,
              tooltip: 'Gửi lại',
              icon: const Icon(Icons.refresh_rounded),
            ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Xoá phiếu',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final DrivingLogEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final date = entry.voucherDate;
    final incomplete = entry.missingFields.isNotEmpty;
    final color = incomplete ? SfColors.amber : SfColors.success;
    return SfCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: SfTouch.min,
            height: SfTouch.min,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: SfRadius.controlR,
            ),
            child: Icon(
              incomplete
                  ? Icons.pending_actions_outlined
                  : Icons.task_alt_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.projectAddress.isEmpty
                      ? 'Chưa có tên công trình'
                      : entry.projectAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.titleCard.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  '${date == null ? 'Chưa có ngày' : '${date.day}/${date.month}/${date.year}'} · ${entry.vehiclePlate.isEmpty ? 'Chưa có biển số' : entry.vehiclePlate}',
                  style: SfType.meta.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  incomplete
                      ? 'Thiếu ${entry.missingFields.join(', ')}'
                      : '${entry.tripCount ?? 0} chuyến · ${entry.totalCost} đ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SfType.meta.copyWith(color: color),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Xoá phiếu',
            icon: Icon(Icons.delete_outline_rounded, color: SfColors.danger),
          ),
          Icon(Icons.chevron_right_rounded, color: p.textMuted),
        ],
      ),
    );
  }
}
