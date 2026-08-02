import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';

class FloodReportScreen extends ConsumerStatefulWidget {
  const FloodReportScreen({super.key});

  @override
  ConsumerState<FloodReportScreen> createState() => _FloodReportScreenState();
}

class _FloodReportScreenState extends ConsumerState<FloodReportScreen> {
  final _address = TextEditingController();
  String _severity = 'MEDIUM';
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
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_position == null) {
      showError(context, 'Chưa lấy được vị trí GPS. Đứng yên vài giây rồi thử lại.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(driverRepositoryProvider)
          .reportFlood(
            position: _position!,
            severity: _severity,
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi điểm ngập đến điều hành')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    final located = _position != null;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: const Text('Báo điểm ngập')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SfSpace.x16,
          SfSpace.x8,
          SfSpace.x16,
          SfSpace.x32,
        ),
        children: [
          const SfScreenTitle(
            title: 'Cập nhật tình trạng đường',
            subtitle:
                'Báo cáo của bạn được dùng để tính lại tuyến cho cả đội xe.',
          ),
          const SizedBox(height: SfSpace.x20),
          SfCard(
            emphasis: located ? null : SfStatus.warning,
            child: Row(
              children: [
                Icon(
                  located
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  color: located ? p.accent : SfColors.amber,
                  size: 26,
                ),
                const SizedBox(width: SfSpace.x16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        located ? 'Đã khoá vị trí' : 'Đang lấy GPS',
                        style: SfType.titleCard.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: SfSpace.x4),
                      Text(
                        located
                            ? '${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}'
                            : 'Đứng ở nơi an toàn, tránh làn xe chạy.',
                        style: SfType.mono.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _locate,
                  tooltip: 'Lấy lại vị trí',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: SfSpace.x24),
          const SfSectionLabel('Mức ngập'),
          const SizedBox(height: SfSpace.x8),
          // Ba mức phân biệt bằng hình + chữ, không chỉ bằng màu.
          _severityOption(
            p,
            value: 'MEDIUM',
            title: 'Ngập vừa',
            detail: 'Nước tới nửa bánh, xe tải còn qua được, chạy chậm.',
            icon: Icons.water_rounded,
            status: SfStatus.warning,
          ),
          const SizedBox(height: SfSpace.x8),
          _severityOption(
            p,
            value: 'HIGH',
            title: 'Ngập nặng',
            detail: 'Nước quá nửa bánh, nguy cơ chết máy. Nên tránh tuyến này.',
            icon: Icons.waves_rounded,
            status: SfStatus.danger,
          ),
          const SizedBox(height: SfSpace.x8),
          _severityOption(
            p,
            value: 'BLOCKED',
            title: 'Chặn hoàn toàn',
            detail: 'Không thể đi qua. Hệ thống sẽ định tuyến lại cho xe khác.',
            icon: Icons.block_rounded,
            status: SfStatus.danger,
          ),
          const SizedBox(height: SfSpace.x24),
          TextField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Mô tả vị trí',
              hintText: 'Ví dụ: hầm chui Thanh Xuân, chiều đi Hà Đông',
              prefixIcon: Icon(Icons.edit_location_alt_outlined),
            ),
          ),
          const SizedBox(height: SfSpace.x24),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else
            SfHoldToConfirm(
              label: 'GIỮ ĐỂ GỬI BÁO CÁO',
              icon: Icons.send_rounded,
              tone: SfColors.teal,
              hint: 'Giữ 2 giây để tránh gửi nhầm khi đang lái.',
              onConfirmed: _submit,
            ),
        ],
      ),
    );
  }

  Widget _severityOption(
    SfPalette p, {
    required String value,
    required String title,
    required String detail,
    required IconData icon,
    required SfStatus status,
  }) {
    final selected = _severity == value;
    final ink = status.inkOf(p);
    return SfCard(
      onTap: () => setState(() => _severity = value),
      emphasis: selected ? status : null,
      child: Row(
        children: [
          Icon(icon, color: selected ? ink : p.textMuted, size: 28),
          const SizedBox(width: SfSpace.x16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SfType.titleCard.copyWith(
                    color: selected ? ink : p.textPrimary,
                  ),
                ),
                const SizedBox(height: SfSpace.x4),
                Text(
                  detail,
                  style: SfType.meta.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? ink : p.textMuted,
          ),
        ],
      ),
    );
  }
}
