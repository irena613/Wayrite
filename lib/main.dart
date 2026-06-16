import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(const TimskiApp());
}

/// Root widget. Апликацијата секогаш стартува на LoginScreen — за реален
/// Firebase backend ова е местото каде што би се проверувал
/// `FirebaseAuth.instance.currentUser` и директно да се скока на HomeShell
/// ако веќе постои активна сесија (види docs/FIREBASE_SETUP.md).
class TimskiApp extends StatelessWidget {
  const TimskiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Тимски',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}
