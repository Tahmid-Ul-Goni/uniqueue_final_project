import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_colors.dart';
import '../../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../../features/receptionist/presentation/receptionist_dashboard_screen.dart';
import '../../../features/student/presentation/student_home_screen.dart';
import '../../../models/app_user.dart';
import '../../../services/catalog_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/queue_service.dart';
import '../data/auth_service.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({this.authService, super.key});

  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    final authService = this.authService ?? context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return LoginScreen(
            onLogin: (email, password) async {
              try {
                await authService.signIn(email, password);
                return null;
              } on AuthFailure catch (error) {
                return error.message;
              }
            },
            onRegister: (name, email, password) async {
              try {
                await authService.registerStudent(
                  name: name,
                  email: email,
                  password: password,
                );
                return null;
              } on AuthFailure catch (error) {
                return error.message;
              }
            },
            onForgotPassword: (email) async {
              try {
                await authService.sendPasswordReset(email);
                return null;
              } on AuthFailure catch (error) {
                return error.message;
              }
            },
          );
        }

        return FutureBuilder<AppUser>(
          future: authService.profileFor(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen(
                  message: 'Loading your UniQueue profile…');
            }
            if (profileSnapshot.hasError || !profileSnapshot.hasData) {
              return _ProfileError(
                message: profileSnapshot.error is AuthFailure
                    ? (profileSnapshot.error! as AuthFailure).message
                    : 'Could not load your profile. Check your connection and retry.',
                onRetry: () => (context as Element).markNeedsBuild(),
                onSignOut: authService.signOut,
              );
            }

            return _RoleHome(
                user: profileSnapshot.data!, authService: authService);
          },
        );
      },
    );
  }
}

class _RoleHome extends StatefulWidget {
  const _RoleHome({required this.user, required this.authService});

  final AppUser user;
  final AuthService authService;

  @override
  State<_RoleHome> createState() => _RoleHomeState();
}

class _RoleHomeState extends State<_RoleHome> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<NotificationService>().attachToUser(widget.user.id);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final queueRepository = context.read<QueueServiceRepository>();
    return switch (widget.user.role) {
      UserRole.student => StudentHomeScreen(
          user: widget.user,
          authService: widget.authService,
          catalogService: catalog,
          queueRepository: queueRepository,
        ),
      UserRole.receptionist => ReceptionistDashboardScreen(
          user: widget.user,
          authService: widget.authService,
          catalogService: catalog,
          queueRepository: queueRepository,
        ),
      UserRole.admin => AdminDashboardScreen(
          authService: widget.authService,
          catalogService: catalog,
        ),
    };
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({this.message = 'Connecting to UniQueue…'});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.red),
              const SizedBox(height: 16),
              Text(message,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

class _ProfileError extends StatelessWidget {
  const _ProfileError(
      {required this.message, required this.onRetry, required this.onSignOut});

  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 40),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
                TextButton(onPressed: onSignOut, child: const Text('Log out')),
              ],
            ),
          ),
        ),
      );
}
