import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';

/// Kiểm tra trước chuyến.
///
/// Nút bắt đầu lái chỉ bật khi tài xế đã xác nhận đủ mọi hạng mục — đây là
/// chốt chặn nghiệp vụ, không phải thủ tục hình thức.
class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({required this.tripId, super.key});

  final int tripId;

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  final _note = TextEditingController();

  /// Khoá gửi lên server giữ nguyên hợp đồng API; nhãn hiển thị gom lại theo
  /// cách tài xế thực sự đi kiểm tra một vòng quanh xe.
  final Map<String, bool> _checks = {
    'documentsChecked': false,
    'tiresChecked': false,
    'brakeChecked': false,
    'lightsChecked': false,
    'cameraChecked': false,
    'exteriorChecked': false,
    'gpsChecked': false,
  };

  bool _busy = false;

  static const _labels = <String, (String, String)>{
    'documentsChecked': (
      'Giấy tờ xe & bằng lái',
      'Đăng kiểm, bảo hiểm, GPLX còn hạn',
    ),
    'tiresChecked': ('Lốp xe', 'Áp suất và bề mặt lốp đạt yêu cầu'),
    'brakeChecked': ('Phanh, đèn tín hiệu', 'Phản hồi phanh và đèn bình thường'),
    'lightsChecked': ('Đèn chiếu sáng', 'Đèn pha, cốt, xi-nhan hoạt động'),
    'cameraChecked': (
      'Camera giám sát trong cabin',
      'Camera đúng vị trí, không bị che',
    ),
    'exteriorChecked': (
      'Chằng buộc hàng hoá',
      'Hàng cố định chắc, không xê dịch',
    ),
    'gpsChecked': (
      'Tình trạng sức khoẻ bản thân',
      'Đủ tỉnh táo, không dùng chất kích thích',
    ),
  };

  static const _icons = <String, IconData>{
    'documentsChecked': Icons.description_rounded,
    'tiresChecked': Icons.trip_origin_rounded,
    'brakeChecked': Icons.do_not_step_rounded,
    'lightsChecked': Icons.lightbulb_rounded,
    'cameraChecked': Icons.videocam_rounded,
    'exteriorChecked': Icons.inventory_2_rounded,
    'gpsChecked': Icons.favorite_rounded,
  };

  int get _done => _checks.values.where((value) => value).length;
  int get _total => _checks.length;
  bool get _complete => _done == _total;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _toggle(String key) {
    HapticFeedback.selectionClick();
    setState(() => _checks[key] = !_checks[key]!);
  }

  Future<void> _submit() async {
    if (!_complete) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(driverRepositoryProvider)
          .submitChecklist(widget.tripId, {
            ..._checks,
            'note': _note.text.trim(),
          });
      if (!mounted) return;
      Navigator.pop(context, result['passed'] == true);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return SfSubScreen(
      title: 'Kiểm tra trước chuyến',
      subtitle: 'Xác nhận đủ $_total mục thì mới bắt đầu được chuyến',
      bottomBar: SfPrimaryAction(
        label: _complete
            ? 'Xác nhận & bắt đầu lái'
            : 'Còn ${_total - _done} mục chưa xác nhận',
        icon: _complete ? Icons.navigation_rounded : null,
        busy: _busy,
        onPressed: _complete ? _submit : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _progressCard(p),
          const SizedBox(height: SfSpace.x14),
          for (final key in _checks.keys) ...[
            _item(key),
            const SizedBox(height: SfSpace.x10),
          ],
          const SizedBox(height: SfSpace.x4),
          TextField(
            controller: _note,
            maxLines: 3,
            style: SfType.bodySm.copyWith(color: p.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Ghi chú cho điều hành',
              hintText: 'Ví dụ: lốp sau mòn nhẹ, cần thay trong tuần',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(SfPalette p) => SfCard(
    padding: const EdgeInsets.all(SfSpace.x14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Đã xác nhận $_done/$_total',
                style: SfType.titleCardSm.copyWith(color: p.textPrimary),
              ),
            ),
            Text(
              '${(_done / _total * 100).round()}%',
              style: SfType.mono.copyWith(
                color: _complete ? SfColors.green700 : p.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: SfSpace.x10),
        SfProgressBar(
          value: _done / _total,
          color: _complete ? SfColors.green700 : SfColors.green600,
        ),
      ],
    ),
  );

  /// Mục đã tick: nền `green050`, viền `borderChecked`, ô vuông xanh có dấu
  /// check. Chưa tick: nền trắng, viền thường, ô rỗng có dấu gạch.
  Widget _item(String key) {
    final p = context.sf;
    final label = _labels[key]!;
    final checked = _checks[key]!;
    return SfCard(
      onTap: () => _toggle(key),
      padding: const EdgeInsets.all(SfSpace.x14),
      background: checked ? SfColors.green050 : null,
      borderColor: checked ? SfColors.borderChecked : null,
      child: Row(
        children: [
          SfIconTile(
            icon: _icons[key]!,
            size: 38,
            background: checked ? SfColors.green100 : p.surfaceAlt,
            foreground: checked ? SfColors.green700 : p.textMuted,
          ),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.$1,
                  style: SfType.titleRow.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  label.$2,
                  style: SfType.caption.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: SfSpace.x12),
          SfCheckBox(checked: checked),
        ],
      ),
    );
  }
}
