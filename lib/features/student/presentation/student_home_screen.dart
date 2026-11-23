import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../../../core/widgets/flat_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../features/auth/data/auth_service.dart';
import '../../../models/app_user.dart';
import '../../../models/department.dart';
import '../../../models/queue_entry.dart';
import '../../../models/queue_service.dart' as service_model;
import '../../../services/catalog_service.dart';
import '../../../services/queue_service.dart';
import 'active_token_screen.dart';
import 'notifications_screen.dart';
import 'service_selection_screen.dart';
import '../../../features/shared/presentation/history_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    required this.user,
    required this.authService,
    required this.catalogService,
    required this.queueRepository,
    super.key,
  });

  final AppUser user;
  final AuthService authService;
  final CatalogService catalogService;
  final QueueServiceRepository queueRepository;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedTab = 0;
  final _departmentsKey = GlobalKey();
  final _homeScrollController = ScrollController();

  AppUser get user => widget.user;
  AuthService get authService => widget.authService;
  CatalogService get catalogService => widget.catalogService;
  QueueServiceRepository get queueRepository => widget.queueRepository;

  @override
  void dispose() {
    _homeScrollController.dispose();
    super.dispose();
  }

  Future<void> _retry(BuildContext context) async {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => StudentHomeScreen(
        user: widget.user,
        authService: widget.authService,
        catalogService: widget.catalogService,
        queueRepository: widget.queueRepository,
      ),
    ));
  }

  Future<void> _selectTab(int index) async {
    setState(() => _selectedTab = index);
    if (index == 0) {
      if (_homeScrollController.hasClients) {
        _homeScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (index == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _departmentsKey.currentContext;
        if (target != null) Scrollable.ensureVisible(target);
      });
      return;
    }
    if (index == 2) {
      try {
        final entries =
            await queueRepository.watchStudentEntries(user.id).first;
        QueueEntry? active;
        for (final entry in entries) {
          if (entry.status.isActive && entry.status != QueueStatus.completed) {
            active = entry;
            break;
          }
        }
        if (!mounted) return;
        if (active == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('You do not have an active token yet.')),
          );
          setState(() => _selectedTab = 0);
          return;
        }
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ActiveTokenScreen(
            entry: active!,
            queueRepository: queueRepository,
            authService: authService,
            averageServiceTime: active.averageServiceTime,
          ),
        ));
        if (mounted) setState(() => _selectedTab = 0);
      } catch (_) {
        if (!mounted) return;
        setState(() => _selectedTab = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open your token. Reconnect and retry.')),
        );
      }
      return;
    }
    if (index == 3 || index == 4) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => index == 3
            ? NotificationsScreen(
                userId: user.id, queueRepository: queueRepository)
            : HistoryScreen(userId: user.id, queueRepository: queueRepository),
      ));
      if (mounted) setState(() => _selectedTab = 0);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('UniQueue'),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: 'Log out',
              onPressed: authService.signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: StreamBuilder<List<QueueEntry>>(
          stream: queueRepository.watchStudentEntries(user.id),
          builder: (context, entrySnapshot) {
            if (entrySnapshot.hasError) {
              return _MessageState(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load your queue',
                detail: 'Check your connection and try again.',
                action: FilledButton(
                    onPressed: () => _retry(context),
                    child: const Text('Retry')),
              );
            }
            if (!entrySnapshot.hasData) return const _LoadingState();
            final entries = entrySnapshot.data!;
            QueueEntry? active;
            for (final entry in entries) {
              if (entry.status.isActive &&
                  entry.status != QueueStatus.completed) {
                active = entry;
                break;
              }
            }

            return CustomScrollView(
              controller: _homeScrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: _WelcomeHero(
                      firstName: user.name.trim().split(' ').first,
                    ),
                  ),
                ),
                if (active != null)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    sliver: SliverToBoxAdapter(
                      child: _ActiveTokenCard(
                        entry: active,
                        queueRepository: queueRepository,
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => ActiveTokenScreen(
                            entry: active!,
                            queueRepository: queueRepository,
                            authService: authService,
                            averageServiceTime: active.averageServiceTime,
                          ),
                        )),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: KeyedSubtree(
                      key: _departmentsKey,
                      child: const Text(
                        'Choose a department',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                StreamBuilder<List<Department>>(
                  stream: catalogService.watchDepartments(),
                  builder: (context, departmentSnapshot) {
                    if (departmentSnapshot.hasError) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MessageState(
                          icon: Icons.error_outline_rounded,
                          title: 'Departments are unavailable',
                          detail: 'Reconnect and reload the app.',
                          action: FilledButton(
                              onPressed: () => _retry(context),
                              child: const Text('Retry')),
                        ),
                      );
                    }
                    if (!departmentSnapshot.hasData) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: ListSkeleton(count: 4),
                      );
                    }
                    final departments = departmentSnapshot.data!;
                    if (departments.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MessageState(
                          icon: Icons.apartment_rounded,
                          title: 'No departments yet',
                          detail:
                              "An admin's first visit adds the demo Finance Office department and service if the catalog is empty. Available departments appear here automatically.",
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverGrid.builder(
                        itemCount: departments.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                        itemBuilder: (context, index) => _DepartmentCard(
                          department: departments[index],
                          catalogService: catalogService,
                          queueRepository: queueRepository,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute<void>(
                            builder: (_) => ServiceSelectionScreen(
                              department: departments[index],
                              user: user,
                              authService: authService,
                              catalogService: catalogService,
                              queueRepository: queueRepository,
                            ),
                          )),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: NavigationBar(
              selectedIndex: _selectedTab,
              onDestinationSelected: _selectTab,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.apartment_outlined),
                  selectedIcon: Icon(Icons.apartment_rounded),
                  label: 'Services',
                ),
                NavigationDestination(
                  icon: Icon(Icons.confirmation_number_outlined),
                  selectedIcon: Icon(Icons.confirmation_number_rounded),
                  label: 'Token',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_none_rounded),
                  selectedIcon: Icon(Icons.notifications_rounded),
                  label: 'Alerts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: 'History',
                ),
              ],
            ),
          ),
        ),
      );
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          border: Border.all(color: AppColors.primaryDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CAMPUS QUEUE',
                      style: TextStyle(
                          color: AppColors.primarySoft,
                          letterSpacing: 1.3,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Welcome, $firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.surface,
                          fontSize: 23,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('Choose a desk and join the live queue.',
                      style: TextStyle(
                          color: AppColors.primarySoft, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.confirmation_number_outlined,
                  color: AppColors.surface, size: 30),
            ),
          ],
        ),
      );
}

class _ActiveTokenCard extends StatelessWidget {
  const _ActiveTokenCard({
    required this.entry,
    required this.queueRepository,
    required this.onTap,
  });

  final QueueEntry entry;
  final QueueServiceRepository queueRepository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.redSoft,
            border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.confirmation_number_outlined,
                  color: AppColors.red, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your active token',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(entry.tokenCode,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    StatusChip(status: entry.status),
                    const SizedBox(height: 6),
                    StreamBuilder<QueuePosition>(
                      stream: queueRepository.watchPosition(entry),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text(
                              'Position will update when connected',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12));
                        }
                        if (!snapshot.hasData) {
                          return const FlatSkeleton(width: 140, height: 12);
                        }
                        final position = snapshot.data!;
                        return Text(
                          'Position ${position.position} · about ${position.waitMinutes} min',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.redDark),
            ],
          ),
        ),
      );
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.department,
    required this.catalogService,
    required this.queueRepository,
    required this.onTap,
  });

  final Department department;
  final CatalogService catalogService;
  final QueueServiceRepository queueRepository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (department.iconKey.toLowerCase()) {
      'account_balance' || 'bank' => Icons.account_balance_rounded,
      'local_hospital' || 'medical_services' => Icons.local_hospital_rounded,
      'school' || 'education' => Icons.school_rounded,
      'library_books' || 'library' => Icons.library_books_rounded,
      'support_agent' => Icons.support_agent_rounded,
      _ => Icons.apartment_rounded,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: StreamBuilder<List<service_model.QueueService>>(
          stream: catalogService.watchDepartmentServices(department.id),
          builder: (context, serviceSnapshot) {
            final services =
                serviceSnapshot.data ?? const <service_model.QueueService>[];
            final firstService = services.isEmpty ? null : services.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 22),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.primary, size: 18),
                ]),
                const SizedBox(height: 8),
                Text(
                  department.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                if (serviceSnapshot.hasError)
                  const Text('Services unavailable',
                      maxLines: 1,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11))
                else if (!serviceSnapshot.hasData)
                  const FlatSkeleton(width: 100, height: 11)
                else if (firstService == null)
                  const Text('Services being set up',
                      maxLines: 1,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11))
                else ...[
                  Text(
                    '${services.length} ${services.length == 1 ? 'service' : 'services'}',
                    maxLines: 1,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: queueRepository.watchPublicQueue(firstService.id),
                    builder: (context, queueSnapshot) {
                      if (queueSnapshot.hasError) {
                        return const Text('Queue count unavailable',
                            maxLines: 1,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11));
                      }
                      if (!queueSnapshot.hasData) {
                        return const FlatSkeleton(width: 132, height: 11);
                      }
                      final waiting = queueSnapshot.data!
                          .where((item) => const {
                                'waiting',
                                'approaching',
                                'called',
                              }.contains(item['status']))
                          .length;
                      return Text(
                        '$waiting waiting at ${firstService.name} · about ${waiting * firstService.averageServiceTime} min',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const ListSkeleton(count: 4);
}

class _MessageState extends StatelessWidget {
  const _MessageState(
      {required this.icon,
      required this.title,
      required this.detail,
      this.action});

  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.red),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 6),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}
