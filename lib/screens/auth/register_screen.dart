import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/app_store.dart';
import '../home/home_shell.dart';

/// Екран за регистрација.
///
/// UI flow: Register -> (успешно) -> HomeShell
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Лозинките не се совпаѓаат.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = appStore.register(
      name: _nameController.text,
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    setState(() => _loading = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрација')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Креирај профил', style: AppTypography.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Име и презиме',
                  controller: _nameController,
                  validator: (v) => (v == null || v.isEmpty) ? 'Внеси име' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Корисничко име',
                  controller: _usernameController,
                  validator: (v) => (v == null || v.isEmpty) ? 'Внеси корисничко име' : null,
                ),
                const SizedBox(height: AppSpacing.md),
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
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Најмалку 6 карактери' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Потврди лозинка',
                  controller: _confirmController,
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Потврди лозинка' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(label: 'Регистрирај се', onPressed: _submit, loading: _loading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
