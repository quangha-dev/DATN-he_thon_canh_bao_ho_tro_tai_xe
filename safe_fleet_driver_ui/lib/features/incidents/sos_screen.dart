import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';

/// SOS — gửi bằng cách GIỮ 2 giây, không phải bấm một lần.
///
/// Tài xế thao tác trong lúc lái hoặc trong lúc hoảng; một cú chạm nhầm không
/// được phép gọi cứu hộ, mà cũng không được bắt qua nhiều bước xác nhận khi
/// tình huống là thật.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  final _description = TextEditingController();
  Map<String, dynamic>? _incident;
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      final result = await ref
          .read(driverRepositoryProvider)
          .sendSos(position: position, description: _description.text.trim());
      if (mounted) setState(() => _incident = result);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: const Text('Cứu hộ khẩn cấp')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SfSpace.x16,
          SfSpace.x8,
          SfSpace.x16,
          SfSpace.x32,
        ),
        children: _incident == null ? _form(p) : _receipt(p),
      ),
    );
  }

  List<Widget> _form(SfPalette p) => [
    const SfScreenTitle(
      title: 'Gọi cứu hộ',
      subtitle: 'Chỉ dùng khi cần trợ giúp ngay lập tức.',
    ),
    const SizedBox(height: SfSpace.x20),
    SfCard(
      emphasis: SfStatus.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Khi gửi, hệ thống sẽ:',
            style: SfType.titleCard.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: SfSpace.x12),
          _bullet(p, 'Gửi vị trí GPS hiện tại của bạn tới tổng đài'),
          _bullet(p, 'Hiện cảnh báo ưu tiên cao nhất trên màn điều hành'),
          _bullet(p, 'Phân công đội cứu hộ và mở timeline xử lý sự cố'),
        ],
      ),
    ),
    const SizedBox(height: SfSpace.x20),
    TextField(
      controller: _description,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Mô tả nhanh (không bắt buộc)',
        hintText: 'Tai nạn, hỏng xe, cần y tế…',
      ),
    ),
    const SizedBox(height: SfSpace.x24),
    if (_busy)
      const Center(child: CircularProgressIndicator())
    else
      SfHoldToConfirm(
        label: 'GIỮ ĐỂ GỌI CỨU HỘ',
        icon: Icons.sos_rounded,
        hint: 'Giữ 2 giây. Thả tay ra là huỷ.',
        onConfirmed: _send,
      ),
  ];

  List<Widget> _receipt(SfPalette p) => [
    const SizedBox(height: SfSpace.x20),
    const Center(
      child: Icon(
        Icons.check_circle_rounded,
        size: 72,
        color: SfColors.success,
      ),
    ),
    const SizedBox(height: SfSpace.x16),
    Text(
      'Tổng đài đã nhận SOS',
      textAlign: TextAlign.center,
      style: SfType.titleScreen.copyWith(color: p.textPrimary),
    ),
    const SizedBox(height: SfSpace.x8),
    Text(
      'Mã ${_incident!['incidentCode'] ?? _incident!['id']}',
      textAlign: TextAlign.center,
      style: SfType.mono.copyWith(color: p.textSecondary),
    ),
    const SizedBox(height: SfSpace.x24),
    SfCard(
      child: SfTimeline(
        entries: [
          const SfTimelineEntry(
            title: 'Đã gửi vị trí và mô tả',
            meta: 'Hoàn tất',
            status: SfStatus.good,
            done: true,
          ),
          SfTimelineEntry(
            title: 'Điều hành tiếp nhận',
            meta: 'Trạng thái hiện tại: ${_incident!['status'] ?? 'OPEN'}',
            status: SfStatus.pending,
            done: _incident!['status'] != 'OPEN',
          ),
          const SfTimelineEntry(
            title: 'Đội cứu hộ tới hiện trường',
            meta: 'Giữ điện thoại mở để nhận liên lạc',
          ),
        ],
      ),
    ),
    const SizedBox(height: SfSpace.x16),
    SfCard(
      emphasis: SfStatus.warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_problem_outlined, color: SfColors.amber),
          const SizedBox(width: SfSpace.x12),
          Expanded(
            child: Text(
              'Nếu an toàn, đưa xe khỏi làn đường và bật đèn cảnh báo. Giữ máy sạc pin để điều hành liên lạc được.',
              style: SfType.body.copyWith(color: p.textPrimary),
            ),
          ),
        ],
      ),
    ),
  ];

  Widget _bullet(SfPalette p, String text) => Padding(
    padding: const EdgeInsets.only(bottom: SfSpace.x8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.circle, size: 6, color: p.textMuted),
        const SizedBox(width: SfSpace.x8),
        Expanded(
          child: Text(
            text,
            style: SfType.body.copyWith(color: p.textSecondary),
          ),
        ),
      ],
    ),
  );
}
