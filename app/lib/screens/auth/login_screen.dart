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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await ref
        .read(authProvider.notifier)
        .login(_emailCtrl.text.trim(), _passCtrl.text);
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
        child: Center(
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
                    'Welcome back',
                    style: AtmosphereTextStyles.h2(c.ink),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AtmosphereTokens.space8),
                  Text(
                    'Sign in to continue',
                    style: AtmosphereTextStyles.body(c.ink3),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AtmosphereTokens.space32),
                  AtmosphereField(
                    label: 'Email',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v != null && v.contains('@')
                        ? null
                        : 'Enter a valid email',
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
                    label: 'Sign In',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AtmosphereTokens.space20),
                  Center(
                    child: TextLinkButton(
                      label: 'Forgot password?',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming soon')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AtmosphereTokens.space20),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No account? ',
                          style: AtmosphereTextStyles.body(c.ink3),
                        ),
                        TextLinkButton(
                          label: 'Register',
                          onPressed: () => context.push('/register'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
