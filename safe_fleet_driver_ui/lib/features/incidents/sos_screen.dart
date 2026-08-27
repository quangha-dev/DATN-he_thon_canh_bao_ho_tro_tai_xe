import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';

/// SOS — gửi bằng cách GIỮ 2 giây, không phải bấm một lần.
///
/// Tài xế thao tác trong lúc lái hoặc trong lúc hoảng; một cú chạm nhầm không
/// được phép gọi cứu hộ, mà cũng không được bắt qua nhiều bước xác nhận khi
/// tình huống là thật. Nền gradient đỏ để không thể nhầm với màn nào khác.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  Map<String, dynamic>? _incident;
  Position? _position;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      if (mounted) setState(() => _position = position);
    } catch (_) {
      // Không có GPS vẫn gửi được SOS — server dùng vị trí cuối đã ghi nhận.
    }
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    HapticFeedback.heavyImpact();
    try {
      final position =
          _position ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
            ),
          );
      final result = await ref
          .read(driverRepositoryProvider)
          .sendSos(position: position, description: '');
      if (mounted) setState(() => _incident = result);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: SfGradients.sos),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(SfSpace.x12),
              child: Row(
                children: [
                  SfIconButton(
                    icon: Icons.arrow_back_rounded,
                    onHero: true,
                    tooltip: 'Quay lại',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: SfSpace.x12),
                  Text(
                    'Cứu hộ khẩn cấp',
                    style: SfType.titleSub.copyWith(
                      color: SfColors.onDanger,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SfSpace.x20,
                  SfSpace.x8,
                  SfSpace.x20,
                  SfSpace.x32,
                ),
                children: [
                  _bigButton(),
                  const SizedBox(height: SfSpace.x32),
                  _attachments(),
                  const SizedBox(height: SfSpace.x20),
                  const _SectionLabelOnDanger('Gọi nhanh'),
                  const SizedBox(height: SfSpace.x12),
                  _quickCall(
                    icon: Icons.headset_mic_rounded,
                    title: 'Trung tâm điều hành',
                    subtitle: '1900 6060 · trực 24/7',
                  ),
                  const SizedBox(height: SfSpace.x10),
                  _quickCall(
                    icon: Icons.medical_services_rounded,
                    title: 'Cấp cứu 115',
                    subtitle: 'Khi có người bị thương',
                  ),
                  const SizedBox(height: SfSpace.x10),
                  _quickCall(
                    icon: Icons.build_rounded,
                    title: 'Cứu hộ kỹ thuật',
                    subtitle: 'Hỏng xe, cần kéo xe',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Nút tròn trắng 216px. Giữ 2 giây mới kích hoạt.
  Widget _bigButton() {
    final sent = _incident != null;
    final button = _HoldCircle(
      sent: sent,
      busy: _busy,
      onConfirmed: _send,
    );
    return Center(
      child: sent
          ? SfPulseRing(
              color: SfColors.onDanger,
              duration: const Duration(milliseconds: 1400),
              maxScale: 1.25,
              child: button,
            )
          : button,
    );
  }

  /// Khối "Gửi kèm": toạ độ, xe & chuyến, tài xế.
  Widget _attachments() {
    final coords = _position == null
        ? 'Đang lấy toạ độ…'
        : '${_position!.latitude.toStringAsFixed(4)}, '
              '${_position!.longitude.toStringAsFixed(4)}';
    return Container(
      padding: const EdgeInsets.all(SfSpace.x16),
      decoration: BoxDecoration(
        color: SfColors.onDanger.withValues(alpha: 0.12),
        borderRadius: SfRadius.cardR,
        border: Border.all(
          color: SfColors.onDanger.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GỬI KÈM',
            style: SfType.label.copyWith(
              color: SfColors.onDanger.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: SfSpace.x12),
          _attachRow(Icons.place_rounded, coords),
          const SizedBox(height: SfSpace.x10),
          _attachRow(
            Icons.local_shipping_rounded,
            'Xe và chuyến đang chạy',
          ),
          const SizedBox(height: SfSpace.x10),
          _attachRow(
            Icons.person_rounded,
            'Hồ sơ tài xế và số liên hệ',
          ),
        ],
      ),
    );
  }

  Widget _attachRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 18, color: SfColors.onDanger),
      const SizedBox(width: SfSpace.x10),
      Expanded(
        child: Text(
          text,
          style: SfType.mono.copyWith(
            color: SfColors.onDanger,
            fontSize: 13.5,
          ),
        ),
      ),
    ],
  );

  Widget _quickCall({
    required IconData icon,
    required String title,
    required String subtitle,
  }) => Container(
    height: 62,
    padding: const EdgeInsets.symmetric(horizontal: SfSpace.x16),
    decoration: BoxDecoration(
      color: SfColors.onDanger.withValues(alpha: 0.12),
      borderRadius: SfRadius.cardSmR,
      border: Border.all(color: SfColors.onDanger.withValues(alpha: 0.24)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 24, color: SfColors.onDanger),
        const SizedBox(width: SfSpace.x14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SfType.titleRow.copyWith(color: SfColors.onDanger),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: SfType.caption.copyWith(
                  color: SfColors.onDanger.withValues(alpha: 0.76),
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.call_rounded,
          size: 20,
          color: SfColors.onDanger.withValues(alpha: 0.72),
        ),
      ],
    ),
  );
}

class _SectionLabelOnDanger extends StatelessWidget {
  const _SectionLabelOnDanger(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: SfType.label.copyWith(
      color: SfColors.onDanger.withValues(alpha: 0.72),
    ),
  );
}

/// Nút tròn 216px: giữ 2 giây, vòng tiến trình chạy quanh viền.
class _HoldCircle extends StatefulWidget {
  const _HoldCircle({
    required this.sent,
    required this.busy,
    required this.onConfirmed,
  });

  final bool sent;
  final bool busy;
  final VoidCallback onConfirmed;

  @override
  State<_HoldCircle> createState() => _HoldCircleState();
}

class _HoldCircleState extends State<_HoldCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onConfirmed();
      _hold.value = 0;
    }
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _start() {
    if (widget.sent || widget.busy) return;
    HapticFeedback.selectionClick();
    _hold.forward();
  }

  void _cancel() {
    if (_hold.isAnimating) _hold.reverse();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _start(),
    onTapUp: (_) => _cancel(),
    onTapCancel: _cancel,
    child: SizedBox(
      width: 216,
      height: 216,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 216,
            height: 216,
            decoration: const BoxDecoration(
              color: SfColors.onDanger,
              shape: BoxShape.circle,
            ),
          ),
          AnimatedBuilder(
            animation: _hold,
            builder: (context, _) => SizedBox(
              width: 210,
              height: 210,
              child: CircularProgressIndicator(
                value: widget.busy ? null : _hold.value,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  SfColors.danger,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.sent ? Icons.check_rounded : Icons.sos_rounded,
                size: 56,
                color: SfColors.dangerStrong,
              ),
              const SizedBox(height: SfSpace.x10),
              Text(
                widget.sent ? 'ĐANG GỌI…' : 'GIỮ 2 GIÂY',
                style: SfType.titleCardSm.copyWith(
                  color: SfColors.dangerStrong,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.sent
                    ? 'Điều hành đã nhận tín hiệu'
                    : 'Gửi tín hiệu cứu hộ',
                textAlign: TextAlign.center,
                style: SfType.caption.copyWith(
                  color: SfColors.dangerStrong.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
