import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/app_store.dart';
import '../home/home_shell.dart';
import 'register_screen.dart';

/// Екран за најава.
///
/// UI flow: Login -> (успешно) -> HomeShell
///          Login -> "Регистрирај се" -> RegisterScreen
///          Login -> "Продолжи со демо профил" -> HomeShell (за брз преглед)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'marija@demo.mk');
  final _passwordController = TextEditingController(text: 'demo123');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await appStore.login(_emailController.text, _passwordController.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    _goHome();
  }

  void _continueAsDemo() {
    appStore.loginAsDemoUser();
    _goHome();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  Text('Тимски', style: AppTypography.displaySmall, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Сподели ги своите постигнувања и навики со пријателите',
                    style: AppTypography.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                    label: 'Е-маил',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.isEmpty) ? 'Внеси е-маил' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Лозинка',
                    controller: _passwordController,
                    obscureText: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'Внеси лозинка' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(label: 'Најави се', onPressed: _submit, loading: _loading),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Продолжи со демо профил',
                    onPressed: _continueAsDemo,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text('Немаш профил? Регистрирај се'),
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
