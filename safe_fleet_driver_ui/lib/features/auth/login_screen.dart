import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/ui.dart';

/// Màn đăng nhập.
///
/// Nền chia hai: dải xanh cao 210px phía trên, nền sáng phía dưới; thẻ trắng
/// bo 22px chứa form đè lên ranh giới.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _bandHeight = 210.0;

  final _formKey = GlobalKey<FormState>();
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(_account.text, _password.text);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "10.0.2.2:8080" — bỏ scheme và đường dẫn API cho gọn chân màn.
  String get _serverLabel {
    final uri = Uri.tryParse(AppConfig.defaultApiUrl);
    if (uri == null || uri.host.isEmpty) return AppConfig.defaultApiUrl;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SfColors.bg,
    body: Stack(
      children: [
        // Dải xanh trên cùng.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _bandHeight,
          child: ColoredBox(color: SfColors.green700),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              SfSpace.x16,
              SfSpace.x24,
              SfSpace.x16,
              SfSpace.x24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Brand(),
                  const SizedBox(height: SfSpace.x24),
                  _card(context),
                  const SizedBox(height: SfSpace.x20),
                  Text(
                    'SafeFleet v1.0 · máy chủ $_serverLabel',
                    textAlign: TextAlign.center,
                    style: SfType.caption.copyWith(
                      color: SfColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _card(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(22)),
      boxShadow: SfShadow.card,
    ),
    child: Container(
      padding: const EdgeInsets.all(SfSpace.x20),
      decoration: BoxDecoration(
        color: SfColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: SfColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SfField(
              controller: _account,
              hint: 'Tài khoản hoặc email',
              icon: Icons.badge_rounded,
              textInputAction: TextInputAction.next,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nhập tài khoản'
                  : null,
            ),
            const SizedBox(height: SfSpace.x12),
            _SfField(
              controller: _password,
              hint: 'Mật khẩu',
              icon: Icons.lock_rounded,
              obscure: _hidden,
              onSubmitted: (_) => _login(),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Nhập mật khẩu' : null,
              suffix: IconButton(
                onPressed: () => setState(() => _hidden = !_hidden),
                tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                iconSize: 20,
                constraints: const BoxConstraints.tightFor(
                  width: SfTouch.min,
                  height: SfTouch.min,
                ),
                color: SfColors.textTertiary,
                icon: Icon(
                  _hidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
            const SizedBox(height: SfSpace.x18),
            SfPrimaryAction(
              label: _busy ? 'Đang xác thực' : 'Đăng nhập',
              icon: Icons.arrow_forward_rounded,
              busy: _busy,
              onPressed: _login,
            ),
            const SizedBox(height: SfSpace.x18),
            const SfInfoBox(
              icon: Icons.wifi_off_rounded,
              text:
                  'Mất mạng vẫn dùng được dữ liệu chuyến đã tải. '
                  'Phiếu và cảnh báo xếp hàng chờ đồng bộ.',
              background: SfColors.bg,
              foreground: SfColors.textSecondaryAlt,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const BrandMark(size: 56, onHero: true),
      const SizedBox(width: SfSpace.x14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SafeFleet',
              style: SfType.titleScreen.copyWith(color: SfColors.onAccent),
            ),
            const SizedBox(height: 2),
            Text(
              'Ứng dụng tài xế · An toàn trước mỗi chuyến đi',
              style: SfType.caption.copyWith(color: SfColors.green300),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Ô nhập cao 54: nền `#F7FBF8`, viền `#E1EBE4`, bo 14, icon dẫn màu xanh.
class _SfField extends StatelessWidget {
  const _SfField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    textInputAction: textInputAction,
    onFieldSubmitted: onSubmitted,
    validator: validator,
    style: SfType.bodySm.copyWith(color: SfColors.textPrimary),
    decoration: InputDecoration(
      hintText: hint,
      constraints: const BoxConstraints(minHeight: 54),
      prefixIcon: Icon(icon, size: 20, color: SfColors.green700),
      prefixIconConstraints: const BoxConstraints.tightFor(
        width: 46,
        height: 46,
      ),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SfSpace.x4,
        vertical: SfSpace.x16,
      ),
    ),
  );
}
