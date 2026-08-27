import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';

/// Báo tình trạng đường (ngập nước hoặc tắc nghẽn).
///
/// Báo cáo của một tài xế được dùng để tính lại tuyến cho cả đội xe, nên form
/// phải nhanh: vị trí tự lấy, loại cảnh báo và mức độ chọn nhanh, ghi chú là
/// tuỳ chọn.
class FloodReportScreen extends ConsumerStatefulWidget {
  const FloodReportScreen({super.key});

  @override
  ConsumerState<FloodReportScreen> createState() => _FloodReportScreenState();
}

class _FloodReportScreenState extends ConsumerState<FloodReportScreen> {
  /// Chip ghi chú nhanh — bấm là thêm vào ô mô tả, không phải gõ tay.
  static const _floodQuickNotes = <String>[
    'Xe con chết máy',
    'Xe tải qua được',
    'Nước đang dâng',
  ];
  static const _trafficQuickNotes = <String>[
    'Di chuyển chậm',
    'Kẹt dài',
    'Tắc cứng',
  ];

  final _address = TextEditingController();
  String _hazardType = 'FLOOD';
  String _severity = 'LOW';
  bool _busy = false;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) setState(() => _position = position);
    } catch (_) {
      // Không có GPS thì tài xế vẫn mô tả được vị trí bằng chữ.
    }
  }

  void _addNote(String note) {
    final current = _address.text.trim();
    if (current.contains(note)) return;
    _address.text = current.isEmpty ? note : '$current · $note';
    setState(() {});
  }

  Future<void> _submit() async {
    if (_position == null) {
      showError(
        context,
        'Chưa lấy được vị trí GPS. Đứng yên vài giây rồi thử lại.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(driverRepositoryProvider)
          .reportFlood(
            position: _position!,
            hazardType: _hazardType,
            severity: _severity,
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          );
      if (!mounted) return;
      final label = _hazardType == 'TRAFFIC_JAM' ? 'điểm kẹt xe' : 'điểm ngập';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã gửi $label đến điều hành')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SfSubScreen(
    title: 'Báo tình trạng đường',
    subtitle: 'Chọn đúng loại để hiển thị icon riêng trên bản đồ',
    bottomBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SfPrimaryAction(
          label: _hazardType == 'TRAFFIC_JAM'
              ? 'Gửi cảnh báo kẹt xe'
              : 'Gửi cảnh báo ngập',
          icon: Icons.send_rounded,
          busy: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: SfSpace.x10),
        Text(
          'Mất mạng vẫn gửi được — báo sẽ tự đồng bộ khi có sóng.',
          textAlign: TextAlign.center,
          style: SfType.caption.copyWith(color: context.sf.textMuted),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _locationCard(),
        const SizedBox(height: SfSpace.x18),
        const SfSectionLabel('Loại cảnh báo'),
        const SizedBox(height: SfSpace.x10),
        Row(
          children: [
            Expanded(
              child: _hazardOption(
                value: 'FLOOD',
                title: 'Ngập nước',
                icon: Icons.water_drop_rounded,
                color: SfColors.info,
              ),
            ),
            const SizedBox(width: SfSpace.x10),
            Expanded(
              child: _hazardOption(
                value: 'TRAFFIC_JAM',
                title: 'Kẹt xe',
                icon: Icons.traffic_rounded,
                color: SfColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: SfSpace.x18),
        SfSectionLabel(
          _hazardType == 'TRAFFIC_JAM' ? 'Mức tắc nghẽn' : 'Mức ngập',
        ),
        const SizedBox(height: SfSpace.x10),
        // Ba mức phân biệt bằng hình + chữ, không chỉ bằng màu.
        _severityOption(
          value: 'LOW',
          title: _hazardType == 'TRAFFIC_JAM'
              ? 'Chậm · vẫn lưu thông'
              : 'Nhẹ · dưới 20cm',
          detail: _hazardType == 'TRAFFIC_JAM'
              ? 'Mật độ xe cao, tốc độ di chuyển chậm.'
              : 'Nước tới mép bánh, xe tải qua được bình thường.',
          dotColor: SfColors.infoLight,
        ),
        const SizedBox(height: SfSpace.x10),
        _severityOption(
          value: 'HIGH',
          title: _hazardType == 'TRAFFIC_JAM'
              ? 'Đông · ùn kéo dài'
              : 'Vừa · 20–40cm',
          detail: _hazardType == 'TRAFFIC_JAM'
              ? 'Dòng xe ùn dài, mất nhiều thời gian để đi qua.'
              : 'Nước tới nửa bánh, chạy chậm, xe con dễ chết máy.',
          dotColor: SfColors.info,
        ),
        const SizedBox(height: SfSpace.x10),
        _severityOption(
          value: 'BLOCKED',
          title: _hazardType == 'TRAFFIC_JAM'
              ? 'Tắc cứng · gần như đứng yên'
              : 'Nặng · trên 40cm',
          detail: _hazardType == 'TRAFFIC_JAM'
              ? 'Nên chọn tuyến khác để tránh khu vực này.'
              : 'Không nên đi qua. Hệ thống sẽ định tuyến lại cho xe khác.',
          dotColor: SfColors.danger,
        ),
        const SizedBox(height: SfSpace.x18),
        const SfSectionLabel('Ghi chú nhanh'),
        const SizedBox(height: SfSpace.x10),
        Wrap(
          spacing: SfSpace.x8,
          runSpacing: SfSpace.x8,
          children: [
            for (final note
                in _hazardType == 'TRAFFIC_JAM'
                    ? _trafficQuickNotes
                    : _floodQuickNotes)
              SfFilterChip(
                label: note,
                selected: _address.text.contains(note),
                onTap: () => _addNote(note),
              ),
          ],
        ),
        const SizedBox(height: SfSpace.x12),
        TextField(
          controller: _address,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          style: SfType.bodySm.copyWith(color: context.sf.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Mô tả vị trí',
            hintText: 'Ví dụ: hầm chui Thanh Xuân, chiều đi Hà Đông',
            alignLabelWithHint: true,
          ),
        ),
      ],
    ),
  );

  Widget _locationCard() {
    final p = context.sf;
    final located = _position != null;
    return SfCard(
      padding: const EdgeInsets.all(SfSpace.x14),
      child: Row(
        children: [
          SfIconTile(
            icon: located
                ? Icons.my_location_rounded
                : Icons.location_searching_rounded,
            background: located ? SfColors.green100 : SfColors.warningBg,
            foreground: located ? SfColors.green700 : SfColors.warning,
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  located ? 'Vị trí hiện tại' : 'Đang lấy GPS',
                  style: SfType.titleRow.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  located
                      ? '${_position!.latitude.toStringAsFixed(4)}, '
                            '${_position!.longitude.toStringAsFixed(4)}'
                      : 'Đứng ở nơi an toàn, tránh làn xe chạy.',
                  style: SfType.caption.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _locate, child: const Text('Đổi')),
        ],
      ),
    );
  }

  Widget _hazardOption({
    required String value,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final selected = _hazardType == value;
    return SfCard(
      onTap: () => setState(() {
        _hazardType = value;
        _address.clear();
      }),
      padding: const EdgeInsets.symmetric(
        horizontal: SfSpace.x12,
        vertical: SfSpace.x14,
      ),
      background: selected ? SfColors.green050 : null,
      borderColor: selected ? SfColors.green700 : null,
      borderWidth: selected ? 1.5 : 1,
      child: Column(
        children: [
          SfIconTile(
            icon: icon,
            background: color.withValues(alpha: .12),
            foreground: color,
          ),
          const SizedBox(height: SfSpace.x8),
          Text(
            title,
            style: SfType.titleRow.copyWith(color: context.sf.textPrimary),
          ),
          const SizedBox(height: 2),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 18,
            color: selected ? SfColors.green700 : context.sf.textMuted,
          ),
        ],
      ),
    );
  }

  /// Mục chọn có viền xanh, nền `green050` và chấm 24px đầy xanh.
  Widget _severityOption({
    required String value,
    required String title,
    required String detail,
    required Color dotColor,
  }) {
    final p = context.sf;
    final selected = _severity == value;
    return SfCard(
      onTap: () => setState(() => _severity = value),
      padding: const EdgeInsets.all(SfSpace.x14),
      background: selected ? SfColors.green050 : null,
      borderColor: selected ? SfColors.green700 : null,
      borderWidth: selected ? 1.5 : 1,
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? SfColors.green700 : Colors.transparent,
              border: Border.all(
                color: selected ? SfColors.green700 : SfColors.dividerStrong,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: SfColors.onAccent,
                  )
                : null,
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: SfType.titleRow.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: SfType.caption.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: SfSpace.x10),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
