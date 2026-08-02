import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';

class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({required this.tripId, super.key});

  final int tripId;

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  final _note = TextEditingController();
  final Map<String, bool> _checks = {
    'exteriorChecked': false,
    'tiresChecked': false,
    'brakeChecked': false,
    'lightsChecked': false,
    'cameraChecked': false,
    'gpsChecked': false,
    'documentsChecked': false,
  };
  bool _busy = false;

  static const labels = {
    'exteriorChecked': ('Ngoại thất', 'Không có hư hỏng bất thường'),
    'tiresChecked': ('Lốp xe', 'Áp suất và bề mặt lốp đạt yêu cầu'),
    'brakeChecked': ('Phanh', 'Phản hồi phanh bình thường'),
    'lightsChecked': ('Đèn', 'Đèn chiếu sáng và tín hiệu hoạt động'),
    'cameraChecked': ('Camera AI', 'Camera quan sát đúng vị trí'),
    'gpsChecked': ('GPS', 'Định vị có tín hiệu ổn định'),
    'documentsChecked': ('Giấy tờ', 'Đủ đăng kiểm, bảo hiểm, bằng lái'),
  };

  static const icons = {
    'exteriorChecked': Icons.local_shipping_outlined,
    'tiresChecked': Icons.trip_origin,
    'brakeChecked': Icons.do_not_step_outlined,
    'lightsChecked': Icons.lightbulb_outline,
    'cameraChecked': Icons.videocam_outlined,
    'gpsChecked': Icons.gps_fixed_rounded,
    'documentsChecked': Icons.description_outlined,
  };

  int get _done => _checks.values.where((value) => value).length;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checks.values.any((value) => !value)) {
      showError(context, 'Còn hạng mục chưa xác nhận. Kiểm tra đủ 7 mục rồi gửi lại.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref.read(driverRepositoryProvider).submitChecklist(
        widget.tripId,
        {..._checks, 'note': _note.text.trim()},
      );
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
    final total = _checks.length;
    final complete = _done == total;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: const Text('Kiểm tra trước chuyến')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SfSpace.x16,
          SfSpace.x8,
          SfSpace.x16,
          SfSpace.x24,
        ),
        children: [
          SfScreenTitle(
            title: '7 bước trước khi lăn bánh',
            subtitle: 'Xác nhận đủ 7 mục thì mới bắt đầu được chuyến.',
            trailing: SfStatusPill(
              '$_done/$total',
              status: complete ? SfStatus.good : SfStatus.pending,
            ),
          ),
          const SizedBox(height: SfSpace.x16),
          ClipRRect(
            borderRadius: SfRadius.pillR,
            child: LinearProgressIndicator(
              value: _done / total,
              minHeight: 8,
              backgroundColor: p.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(
                complete ? SfColors.success : p.accent,
              ),
            ),
          ),
          const SizedBox(height: SfSpace.x20),
          for (final key in _checks.keys)
            Padding(
              padding: const EdgeInsets.only(bottom: SfSpace.x8),
              child: _item(p, key),
            ),
          const SizedBox(height: SfSpace.x12),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Ghi chú cho điều hành',
              hintText: 'Ví dụ: lốp sau mòn nhẹ, cần thay trong tuần',
            ),
          ),
          const SizedBox(height: SfSpace.x20),
          SfPrimaryAction(
            label: complete
                ? 'Xác nhận xe đủ điều kiện'
                : 'Còn ${total - _done} mục chưa kiểm tra',
            icon: Icons.verified_outlined,
            busy: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _item(SfPalette p, String key) {
    final label = labels[key]!;
    final checked = _checks[key]!;
    return SfCard(
      onTap: () => setState(() => _checks[key] = !checked),
      emphasis: checked ? SfStatus.good : null,
      padding: const EdgeInsets.symmetric(
        horizontal: SfSpace.x16,
        vertical: SfSpace.x12,
      ),
      child: Row(
        children: [
          Icon(
            icons[key],
            color: checked ? SfColors.success : p.textSecondary,
            size: 24,
          ),
          const SizedBox(width: SfSpace.x16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.$1,
                  style: SfType.titleCard.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  label.$2,
                  style: SfType.meta.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: checked,
            onChanged: (value) => setState(() => _checks[key] = value),
          ),
        ],
      ),
    );
  }
}
