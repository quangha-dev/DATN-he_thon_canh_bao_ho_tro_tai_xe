import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/widgets/ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

  @override
  Widget build(BuildContext context) {
    final p = context.sf;
    return Scaffold(
      backgroundColor: p.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SfSpace.x24,
              vertical: SfSpace.x24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: BrandMark(size: 68),
                    ),
                    const SizedBox(height: SfSpace.x32),
                    Text(
                      'Sẵn sàng cho\nmột chuyến đi an toàn.',
                      style: SfType.titleScreen.copyWith(
                        color: p.textPrimary,
                        fontSize: 30,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: SfSpace.x12),
                    Text(
                      'Đăng nhập bằng tài khoản tài xế do điều phối cấp.',
                      style: SfType.body.copyWith(color: p.textSecondary),
                    ),
                    const SizedBox(height: SfSpace.x32),
                    TextFormField(
                      controller: _account,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tài khoản hoặc email',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Nhập tài khoản'
                          : null,
                    ),
                    const SizedBox(height: SfSpace.x12),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidden,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidden = !_hidden),
                          tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          icon: Icon(
                            _hidden
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Nhập mật khẩu'
                          : null,
                    ),
                    const SizedBox(height: SfSpace.x20),
                    SfPrimaryAction(
                      label: _busy ? 'Đang xác thực' : 'Đăng nhập',
                      icon: Icons.arrow_forward_rounded,
                      busy: _busy,
                      onPressed: _login,
                    ),
                    const SizedBox(height: SfSpace.x20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 16,
                          color: p.accent,
                        ),
                        const SizedBox(width: SfSpace.x8),
                        Text(
                          'Kết nối được mã hoá, phiên đăng nhập lưu trên máy',
                          style: SfType.meta.copyWith(color: p.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
