import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'data/app_store.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await appStore.restoreSession();
  runApp(const TimskiApp());
}

class TimskiApp extends StatelessWidget {
  const TimskiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Тимски',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: appStore.isLoggedIn ? const HomeShell() : const LoginScreen(),
    );
  }
}
