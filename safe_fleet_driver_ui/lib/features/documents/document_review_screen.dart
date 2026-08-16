import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';
import 'document_image_screen.dart';
import 'document_ocr_queue_repository.dart';
import 'driving_log_entry.dart';

class DocumentReviewScreen extends ConsumerStatefulWidget {
  const DocumentReviewScreen({
    required this.initialEntry,
    this.serverOcrManagedByQueue = false,
    this.serverOcrCompleted = false,
    super.key,
  });

  final DrivingLogEntry initialEntry;
  final bool serverOcrManagedByQueue;
  final bool serverOcrCompleted;

  @override
  ConsumerState<DocumentReviewScreen> createState() =>
      _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends ConsumerState<DocumentReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late DrivingLogEntry _entry;
  late DateTime? _date = widget.initialEntry.voucherDate;
  late final _driver = TextEditingController(
    text: widget.initialEntry.driverName,
  );
  late final _assistant = TextEditingController(
    text: widget.initialEntry.assistantName,
  );
  late final _plate = TextEditingController(
    text: widget.initialEntry.vehiclePlate,
  );
  late final _project = TextEditingController(
    text: widget.initialEntry.projectAddress,
  );
  late final _trips = TextEditingController(
    text: widget.initialEntry.tripCount?.toString() ?? '',
  );
  late final _meal = TextEditingController(
    text: widget.initialEntry.mealCost?.toString() ?? '',
  );
  late final _rule = TextEditingController(
    text: widget.initialEntry.ruleCost?.toString() ?? '',
  );
  late final _tyre = TextEditingController(
    text: widget.initialEntry.tyreCost?.toString() ?? '',
  );
  late final _other = TextEditingController(
    text: widget.initialEntry.otherCost?.toString() ?? '',
  );
  late final _manager = TextEditingController(
    text: widget.initialEntry.managerConfirmation,
  );
  late final _voucher = TextEditingController(
    text: widget.initialEntry.voucherNumber,
  );
  var _saving = false;
  var _projectEditedByUser = false;
  var _plateEditedByUser = false;
  var _applyingOcrResult = false;
  late bool _serverOcrCompleted = widget.serverOcrCompleted;
  StreamSubscription<List<DocumentOcrQueueItem>>? _ocrQueueSubscription;

  bool get _serverOcrPending =>
      widget.serverOcrManagedByQueue && !_serverOcrCompleted;

  @override
  void initState() {
    super.initState();
    _entry = widget.initialEntry;
    _project.addListener(_trackProjectEdit);
    _plate.addListener(_trackPlateEdit);
    if (_serverOcrPending) {
      final queue = ref.read(documentOcrSyncQueueProvider);
      _ocrQueueSubscription = queue.changes.listen(
        (items) => unawaited(_refreshOcrState(items)),
      );
      unawaited(_refreshOcrState());
    }
  }

  void _trackProjectEdit() {
    if (_applyingOcrResult) return;
    _projectEditedByUser = true;
  }

  void _trackPlateEdit() {
    if (_applyingOcrResult) return;
    _plateEditedByUser = true;
  }

  Future<void> _refreshOcrState([List<DocumentOcrQueueItem>? items]) async {
    try {
      if (!_serverOcrPending) return;
      final queue = ref.read(documentOcrSyncQueueProvider);
      final currentQueue = items ?? await queue.list();
      if (currentQueue.any((item) => item.entryId == _entry.id)) return;
      final latest = await ref
          .read(drivingLogRepositoryProvider)
          .find(_entry.id);
      if (latest == null || latest.isComputerOcrPending || !mounted) return;

      _applyingOcrResult = true;
      try {
        setState(() {
          _entry = latest;
          _date = latest.voucherDate;
          _serverOcrCompleted = true;
        });
        _voucher.text = latest.voucherNumber;
        _plate.text = latest.vehiclePlate;
        _project.text = latest.projectAddress;
        if (latest.driverName.trim().isNotEmpty) {
          _driver.text = latest.driverName;
        }
        _trips.text = latest.tripCount?.toString() ?? '';
      } finally {
        _applyingOcrResult = false;
      }
    } catch (_) {
      // Đồng bộ nền sẽ phát sự kiện tiếp theo. Không để lỗi đọc cục bộ ngắn
      // hạn làm đóng form hoặc làm người dùng tưởng tác vụ OCR bị ngắt.
    }
  }

  @override
  void dispose() {
    unawaited(_ocrQueueSubscription?.cancel());
    _project.removeListener(_trackProjectEdit);
    _plate.removeListener(_trackPlateEdit);
    for (final controller in [
      _driver,
      _assistant,
      _plate,
      _project,
      _trips,
      _meal,
      _rule,
      _tyre,
      _other,
      _manager,
      _voucher,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 31)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  int? _number(TextEditingController controller) {
    final normalized = controller.text.replaceAll(RegExp(r'[^0-9-]'), '');
    return normalized.isEmpty ? null : int.tryParse(normalized);
  }

  DrivingLogEntry _entryFromForm({DrivingLogEntry? latestEntry}) {
    final base = latestEntry ?? _entry;
    final formProject = _project.text.trim();
    final preserveLockedOcrFields = _serverOcrPending;
    // Nếu OCR vừa hoàn thành trong lúc form đang mở và người dùng không sửa
    // ô công trình, giữ kết quả mới nhất thay vì ghi đè bằng giá trị cũ.
    final projectAddress = preserveLockedOcrFields
        ? base.projectAddress
        : !_projectEditedByUser &&
              !base.isComputerOcrPending &&
              base.projectAddress.trim().isNotEmpty
        ? base.projectAddress
        : formProject;
    final voucherDate = preserveLockedOcrFields ? base.voucherDate : _date;
    final driverName = preserveLockedOcrFields
        ? base.driverName
        : _driver.text.trim();
    final vehiclePlate = preserveLockedOcrFields
        ? base.vehiclePlate
        : _plate.text.trim().toUpperCase();
    final tripCount = preserveLockedOcrFields
        ? base.tripCount
        : _number(_trips);
    final voucherNumber = preserveLockedOcrFields
        ? base.voucherNumber
        : _voucher.text.trim();
    final operationalComplete =
        voucherDate != null &&
        driverName.isNotEmpty &&
        projectAddress.isNotEmpty &&
        (tripCount ?? 0) > 0;
    return base.copyWith(
      voucherDate: voucherDate,
      clearVoucherDate: voucherDate == null,
      driverName: driverName,
      assistantName: _assistant.text.trim(),
      vehiclePlate: vehiclePlate,
      projectAddress: projectAddress,
      tripCount: tripCount,
      clearTripCount: tripCount == null,
      mealCost: _number(_meal),
      clearMealCost: _number(_meal) == null,
      ruleCost: _number(_rule),
      clearRuleCost: _number(_rule) == null,
      tyreCost: _number(_tyre),
      clearTyreCost: _number(_tyre) == null,
      otherCost: _number(_other),
      clearOtherCost: _number(_other) == null,
      managerConfirmation: _manager.text.trim(),
      voucherNumber: voucherNumber,
      fieldConfidences: {
        ...base.fieldConfidences,
        if (_projectEditedByUser) 'projectAddress': 1,
        if (_plateEditedByUser) 'vehiclePlate': 1,
      },
      // Việc người dùng nhập đủ trường không đồng nghĩa OCR máy tính đã xong.
      // Trong luồng hàng đợi, phiếu phải tiếp tục là bản nháp cho tới khi
      // DocumentOcrSyncQueue nhận và ghép kết quả thật từ máy chủ.
      status: _serverOcrPending && base.isComputerOcrPending
          ? DrivingLogStatus.draft
          : operationalComplete
          ? DrivingLogStatus.verified
          : DrivingLogStatus.draft,
    );
  }

  Future<void> _save() async {
    if (_entry.qualityLevel == ScanQualityLevel.red) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(drivingLogRepositoryProvider);
      final latest = await repository.find(_entry.id) ?? _entry;
      final updated = _entryFromForm(latestEntry: latest);
      await repository.save(updated);
      _entry = updated;
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final entry = _entry;
    final red = entry.qualityLevel == ScanQualityLevel.red;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: Text(
          _serverOcrPending || _serverOcrCompleted
              ? 'Bổ sung dữ liệu phiếu'
              : 'Đối chiếu phiếu',
        ),
        actions: [
          TextButton(
            onPressed: _saving || red ? null : _save,
            child: const Text('Lưu'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: _ImageComparisonHeader(
                entry: entry,
                onOpen: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentImageScreen(entry: entry),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: SfSpace.screen,
                  children: [
                    if (_serverOcrPending)
                      const _QueuedOcrEditingBanner()
                    else ...[
                      if (!_serverOcrCompleted) ...[
                        _QualityBanner(entry),
                        const SizedBox(height: SfSpace.x8),
                      ],
                      _ExtractionBanner(entry),
                      if (_serverOcrCompleted) ...[
                        const SizedBox(height: SfSpace.x8),
                        const _CompletedOcrEditingBanner(),
                      ],
                    ],
                    if (red) ...[
                      const SizedBox(height: SfSpace.x16),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Chụp lại phiếu'),
                      ),
                    ] else ...[
                      const SizedBox(height: SfSpace.x16),
                      Text(
                        _serverOcrPending
                            ? 'Các trường có biểu tượng khóa đang được máy tính OCR và chỉ sửa được sau khi xử lý xong. Bạn vẫn có thể nhập, lưu các trường bổ sung ngay.'
                            : _serverOcrCompleted
                            ? 'OCR máy tính đã hoàn tất. Bổ sung các trường còn thiếu để hoàn thiện phiếu; form này không gửi lại OCR.'
                            : 'So sánh từng ô với ảnh phía trên. Ô vàng là dữ liệu OCR cần kiểm tra; ô đỏ là dữ liệu bắt buộc còn thiếu.',
                        style: SfType.meta.copyWith(color: p.textSecondary),
                      ),
                      const SizedBox(height: SfSpace.x20),
                      const SfSectionLabel('Thông tin trên phiếu'),
                      const SizedBox(height: SfSpace.x8),
                      _dateField(),
                      _field(
                        fieldKey: const ValueKey('voucher-field'),
                        controller: _voucher,
                        label: 'Số phiếu',
                        confidenceKey: 'voucherNumber',
                        lockedByOcr: _serverOcrPending,
                      ),
                      _field(
                        fieldKey: const ValueKey('vehicle-plate-field'),
                        controller: _plate,
                        label: 'Biển số xe',
                        confidenceKey: 'vehiclePlate',
                        lockedByOcr: _serverOcrPending,
                      ),
                      _field(
                        fieldKey: const ValueKey('project-address-field'),
                        controller: _project,
                        label: _serverOcrPending
                            ? 'Tên - địa chỉ công trình (OCR sẽ bổ sung)'
                            : 'Tên - địa chỉ công trình *',
                        confidenceKey: 'projectAddress',
                        maxLines: 3,
                        requiredField: !_serverOcrPending,
                        lockedByOcr: _serverOcrPending,
                      ),
                      const SizedBox(height: SfSpace.x12),
                      const SfSectionLabel('Thông tin nhật trình'),
                      const SizedBox(height: SfSpace.x8),
                      _field(
                        fieldKey: const ValueKey('driver-name-field'),
                        controller: _driver,
                        label: _serverOcrPending
                            ? 'Tên lái xe'
                            : 'Tên lái xe *',
                        confidenceKey: 'driverName',
                        requiredField: !_serverOcrPending,
                        lockedByOcr: _serverOcrPending,
                      ),
                      _field(
                        fieldKey: const ValueKey('assistant-name-field'),
                        controller: _assistant,
                        label: 'Tên phụ xe',
                      ),
                      _field(
                        fieldKey: const ValueKey('trip-count-field'),
                        controller: _trips,
                        label: _serverOcrPending ? 'Số chuyến' : 'Số chuyến *',
                        confidenceKey: 'tripCount',
                        keyboardType: TextInputType.number,
                        requiredField: !_serverOcrPending,
                        lockedByOcr: _serverOcrPending,
                      ),
                      const SizedBox(height: SfSpace.x12),
                      const SfSectionLabel('Chi phí bổ sung'),
                      const SizedBox(height: SfSpace.x8),
                      _moneyField(_meal, 'Ăn ca'),
                      _moneyField(_rule, 'Luật'),
                      _moneyField(_tyre, 'Làm lốp'),
                      _moneyField(_other, 'Chi phí khác'),
                      _field(
                        fieldKey: const ValueKey('manager-confirmation-field'),
                        controller: _manager,
                        label: 'Xác nhận người quản lý',
                        helper: 'Có thể bổ sung sau khi quản lý xác nhận.',
                      ),
                      const SizedBox(height: SfSpace.x16),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving
                              ? 'Đang lưu...'
                              : _serverOcrPending
                              ? 'Lưu thông tin bổ sung'
                              : _serverOcrCompleted
                              ? 'Lưu thông tin bổ sung'
                              : 'Xác nhận và lưu trên máy',
                        ),
                      ),
                      const SizedBox(height: SfSpace.x24),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField() {
    final confidence = _entry.fieldConfidences['voucherDate'] ?? 0;
    final lockedByOcr = _serverOcrPending;
    return Padding(
      padding: const EdgeInsets.only(bottom: SfSpace.x12),
      child: InkWell(
        key: const ValueKey('voucher-date-field'),
        borderRadius: SfRadius.controlR,
        onTap: lockedByOcr ? null : _pickDate,
        child: InputDecorator(
          decoration: _decoration(
            label: _serverOcrPending ? 'Ngày' : 'Ngày *',
            confidence: confidence,
            missing: _date == null,
            lockedByOcr: lockedByOcr,
            suffixIcon: Icon(
              lockedByOcr
                  ? Icons.lock_clock_outlined
                  : Icons.calendar_month_outlined,
            ),
          ),
          child: Text(
            _date == null
                ? 'Chưa có dữ liệu'
                : '${_date!.day}/${_date!.month}/${_date!.year}',
            style: SfType.body.copyWith(color: context.sf.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _moneyField(TextEditingController controller, String label) => _field(
    controller: controller,
    label: label,
    keyboardType: TextInputType.number,
    suffixText: 'đ',
  );

  Widget _field({
    Key? fieldKey,
    required TextEditingController controller,
    required String label,
    String? confidenceKey,
    String? helper,
    String? suffixText,
    int maxLines = 1,
    bool requiredField = false,
    bool lockedByOcr = false,
    TextInputType? keyboardType,
  }) {
    final confidence = confidenceKey == null
        ? 1.0
        : _entry.fieldConfidences[confidenceKey] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: SfSpace.x12),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        readOnly: lockedByOcr,
        canRequestFocus: !lockedByOcr,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: keyboardType == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        validator: requiredField
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Cần bổ sung trường này'
                  : null
            : null,
        decoration: _decoration(
          label: label,
          confidence: confidence,
          missing: requiredField && controller.text.trim().isEmpty,
          helper: helper,
          suffixText: suffixText,
          lockedByOcr: lockedByOcr,
          suffixIcon: lockedByOcr
              ? const Icon(Icons.lock_clock_outlined)
              : null,
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required double confidence,
    required bool missing,
    String? helper,
    String? suffixText,
    Widget? suffixIcon,
    bool lockedByOcr = false,
  }) {
    final color = lockedByOcr
        ? context.sf.border
        : missing
        ? SfColors.danger
        : confidence < 0.8
        ? SfColors.amber
        : context.sf.border;
    return InputDecoration(
      labelText: label,
      helperText: lockedByOcr
          ? 'Máy tính đang nhận dạng trường này'
          : helper ?? (confidence < 0.8 ? 'Cần đối chiếu với ảnh' : null),
      suffixText: suffixText,
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: SfRadius.controlR,
        borderSide: BorderSide(color: color),
      ),
    );
  }
}

class _ImageComparisonHeader extends StatelessWidget {
  const _ImageComparisonHeader({required this.entry, required this.onOpen});

  final DrivingLogEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: SfColors.darkBg,
    child: InkWell(
      onTap: onOpen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (File(entry.imagePath).existsSync())
            Image.file(File(entry.imagePath), fit: BoxFit.contain)
          else
            const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: SfColors.darkTextSecondary,
              ),
            ),
          Positioned(
            right: SfSpace.x12,
            bottom: SfSpace.x12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: SfColors.scrim,
                borderRadius: SfRadius.pillR,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SfSpace.x12,
                  vertical: SfSpace.x8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.zoom_in_rounded,
                      color: SfColors.darkTextPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: SfSpace.x4),
                    Text(
                      'Chạm để phóng to',
                      style: SfType.meta.copyWith(
                        color: SfColors.darkTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _QualityBanner extends StatelessWidget {
  const _QualityBanner(this.entry);

  final DrivingLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final (color, tint, label, icon) = switch (entry.qualityLevel) {
      ScanQualityLevel.green => (
        SfColors.success,
        context.sf.goodTint,
        'Chất lượng ảnh · Xanh',
        Icons.check_circle_outline,
      ),
      ScanQualityLevel.yellow => (
        SfColors.amber,
        context.sf.warnTint,
        'Chất lượng ảnh · Vàng',
        Icons.warning_amber_rounded,
      ),
      ScanQualityLevel.red => (
        SfColors.danger,
        context.sf.dangerTint,
        'Chất lượng ảnh · Đỏ',
        Icons.cancel_outlined,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(SfSpace.x12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: SfRadius.controlR,
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · ${entry.qualityScore}/100',
                  style: SfType.titleCard.copyWith(color: color),
                ),
                if (entry.qualityIssues.isNotEmpty) ...[
                  const SizedBox(height: SfSpace.x4),
                  Text(
                    entry.qualityIssues.join(' · '),
                    style: SfType.meta.copyWith(
                      color: context.sf.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueuedOcrEditingBanner extends StatelessWidget {
  const _QueuedOcrEditingBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(SfSpace.x12),
    decoration: BoxDecoration(
      color: context.sf.accentTint,
      borderRadius: SfRadius.controlR,
      border: Border.all(color: context.sf.accent),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.cloud_sync_outlined, color: context.sf.accent),
        const SizedBox(width: SfSpace.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Máy tính đang xử lý OCR',
                style: SfType.titleCard.copyWith(color: context.sf.accent),
              ),
              const SizedBox(height: SfSpace.x4),
              Text(
                'Ngày, số phiếu, biển số, tên công trình, tên lái xe và số chuyến đang được khóa để chờ OCR. Bạn vẫn có thể nhập và lưu phụ xe, chi phí, xác nhận quản lý; kết quả sẽ được ghép mà không làm mất dữ liệu.',
                style: SfType.meta.copyWith(color: context.sf.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CompletedOcrEditingBanner extends StatelessWidget {
  const _CompletedOcrEditingBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(SfSpace.x12),
    decoration: BoxDecoration(
      color: context.sf.goodTint,
      borderRadius: SfRadius.controlR,
      border: Border.all(color: SfColors.success),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_done_outlined, color: SfColors.success),
        const SizedBox(width: SfSpace.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OCR máy tính đã hoàn tất',
                style: SfType.titleCard.copyWith(color: SfColors.success),
              ),
              const SizedBox(height: SfSpace.x4),
              Text(
                'Kết quả đã được ghép vào phiếu. Chỉ cần nhập các trường còn thiếu; ứng dụng sẽ không khởi chạy thêm một tác vụ OCR khác.',
                style: SfType.meta.copyWith(color: context.sf.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ExtractionBanner extends StatelessWidget {
  const _ExtractionBanner(this.entry);

  final DrivingLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final dateConfidence = entry.fieldConfidences['voucherDate'] ?? 0;
    final projectConfidence = entry.fieldConfidences['projectAddress'] ?? 0;
    final dateReady = entry.voucherDate != null && dateConfidence >= 0.8;
    final projectReady =
        entry.projectAddress.trim().isNotEmpty && projectConfidence >= 0.8;
    final ready = dateReady && projectReady;
    final missing = <String>[
      if (!dateReady) 'ngày tháng',
      if (!projectReady) 'tên công trình',
    ];
    final color = ready ? SfColors.success : SfColors.amber;
    final tint = ready ? context.sf.goodTint : context.sf.warnTint;
    return Container(
      padding: const EdgeInsets.all(SfSpace.x12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: SfRadius.controlR,
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.fact_check_outlined : Icons.manage_search_outlined,
            color: color,
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready
                      ? 'Dữ liệu OCR · Đã nhận dạng'
                      : 'Dữ liệu OCR · Cần đối chiếu',
                  style: SfType.titleCard.copyWith(color: color),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  ready
                      ? 'Ngày tháng và tên công trình đã được điền. Hãy so sánh lại với ảnh trước khi lưu.'
                      : 'Cần kiểm tra hoặc bổ sung: ${missing.join(', ')}. Chất lượng ảnh không bị hạ màu vì trường OCR còn thiếu.',
                  style: SfType.meta.copyWith(color: context.sf.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
