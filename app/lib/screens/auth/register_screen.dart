import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/palette.dart';
import '../../design/text_styles.dart';
import '../../design/tokens.dart';
import '../../widgets/atoms/dot_logo.dart';
import '../../widgets/atoms/field.dart';
import '../../widgets/atoms/primary_button.dart';
import '../../widgets/atoms/text_button_link.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).register(
          _emailCtrl.text.trim(),
          _passCtrl.text,
          _nameCtrl.text.trim(),
        );
    if (mounted) setState(() => _loading = false);

    final authState = ref.read(authProvider);
    if (mounted && authState.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authState.error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AtmosphereTokens.space24,
            vertical: AtmosphereTokens.space32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: AtmosphereDotLogo(
                    size: 64,
                    color: c.brand,
                  ),
                ),
                const SizedBox(height: AtmosphereTokens.space24),
                Text(
                  'Create Account',
                  style: AtmosphereTextStyles.h2(c.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AtmosphereTokens.space8),
                Text(
                  'Join Smart Air to monitor your indoor air quality',
                  style: AtmosphereTextStyles.body(c.ink3),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AtmosphereTokens.space32),
                AtmosphereField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  validator: (v) =>
                      v != null && v.isNotEmpty ? null : 'Name required',
                ),
                const SizedBox(height: AtmosphereTokens.space20),
                AtmosphereField(
                  label: 'Email',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v != null && v.contains('@')
                      ? null
                      : 'Valid email required',
                ),
                const SizedBox(height: AtmosphereTokens.space20),
                AtmosphereField(
                  label: 'Password',
                  controller: _passCtrl,
                  obscure: true,
                  validator: (v) =>
                      v != null && v.length >= 6 ? null : 'Min 6 characters',
                ),
                const SizedBox(height: AtmosphereTokens.space32),
                PrimaryButton(
                  label: 'Create Account',
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AtmosphereTokens.space20),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AtmosphereTextStyles.body(c.ink3),
                      ),
                      TextLinkButton(
                        label: 'Sign In',
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
