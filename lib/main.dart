import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'data/app_store.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';

// Flip to true only when running: firebase emulators:start --only functions.
// Use '10.0.2.2' for the Android emulator, or the PC's LAN IPv4 (ipconfig)
// for a physical device. Leave false to talk to deployed Cloud Functions.
const _useEmulator = false;
const _emulatorHost = '192.168.100.10';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_useEmulator) {
    FirebaseFunctions.instanceFor(region: 'europe-west1')
        .useFunctionsEmulator(_emulatorHost, 5001);
  }

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
