import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/app_store.dart';

/// Екран за измена на лични податоци (име, корисничко име, биографија).
///
/// UI flow: EditProfile -> "Зачувај" -> назад на ProfileScreen (со ажурирани податоци)
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final user = appStore.currentUser!;
    _nameController = TextEditingController(text: user.name);
    _usernameController = TextEditingController(text: user.username);
    _bioController = TextEditingController(text: user.bio);
    _emailController = TextEditingController(text: user.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    appStore.updateProfile(
      name: _nameController.text,
      username: _usernameController.text,
      bio: _bioController.text,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Уреди профил')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                readOnly: true,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Биографија',
                controller: _bioController,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Зачувај', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
