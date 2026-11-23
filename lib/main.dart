import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_colors.dart';
import 'app/app_theme.dart';
import 'firebase_options.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'services/catalog_service.dart';
import 'services/notification_service.dart';
import 'services/queue_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  NotificationService? notificationService;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    notificationService = NotificationService();
    await notificationService.initializeForegroundDisplay();
    firebaseReady = true;
  } catch (_) {
    // Keep the app launchable before the owner creates and configures a Firebase project.
  }
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(notificationService: notificationService),
        ),
        Provider<CatalogService>(create: (_) => CatalogService()),
        Provider<QueueServiceRepository>(
            create: (_) => QueueServiceRepository()),
        if (notificationService != null)
          Provider<NotificationService>.value(value: notificationService),
      ],
      child: UniQueueApp(firebaseReady: firebaseReady),
    ),
  );
}

class UniQueueApp extends StatelessWidget {
  const UniQueueApp({required this.firebaseReady, super.key});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniQueue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: firebaseReady ? const AuthGate() : const FirebaseSetupScreen(),
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        color: AppColors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Connect Firebase',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'Create the project in your Firebase account, then register the Flutter app. '
                      'The Firebase backend is required for sign-in and live queue data.',
                      style: TextStyle(
                          color: AppColors.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    const _SetupStep(
                      number: '1',
                      text: 'Create a project at console.firebase.google.com.',
                    ),
                    const _SetupStep(
                      number: '2',
                      text:
                          'Enable Email/Password in Authentication and create a Cloud Firestore database.',
                    ),
                    const _SetupStep(
                      number: '3',
                      text: 'From this folder, run: flutterfire configure',
                    ),
                    const _SetupStep(
                      number: '4',
                      text:
                          'Register Android as com.cityuniversity.uniqueue (and iOS if needed), then restart the app.',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const SelectableText(
                        'Project path: Final Project/Final Project\n'
                        'Firebase console: https://console.firebase.google.com',
                        style: TextStyle(
                            color: AppColors.textPrimary, height: 1.6),
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

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: AppColors.redSoft, shape: BoxShape.circle),
              child: Text(
                number,
                style: const TextStyle(
                    color: AppColors.redDark, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
          ],
        ),
      );
}
