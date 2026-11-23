import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../../../core/widgets/flat_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../features/auth/data/auth_service.dart';
import '../../../features/shared/presentation/history_screen.dart';
import '../../../models/app_user.dart';
import '../../../models/queue_entry.dart';
import '../../../models/queue_service.dart';
import '../../../services/catalog_service.dart';
import '../../../services/queue_service.dart';
import 'qr_scan_screen.dart';

class ReceptionistDashboardScreen extends StatefulWidget {
  const ReceptionistDashboardScreen({
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
  State<ReceptionistDashboardScreen> createState() =>
      _ReceptionistDashboardScreenState();
}

class _ReceptionistDashboardScreenState
    extends State<ReceptionistDashboardScreen> {
  String? _selectedServiceId;
  int _selectedNavigation = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      final serviceId = _selectedServiceId;
      if (serviceId != null) {
        widget.queueRepository.checkTimers(serviceId).catchError((_) {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _callNext(List<QueueEntry> entries) async {
    if (entries.any((entry) =>
        entry.status == QueueStatus.called ||
        entry.status == QueueStatus.serving)) {
      return;
    }
    QueueEntry? next;
    for (final entry in entries) {
      if (entry.status == QueueStatus.approaching ||
          entry.status == QueueStatus.waiting) {
        next = entry;
        break;
      }
    }
    if (next == null) return;
    try {
      if (next.status == QueueStatus.waiting) {
        await widget.queueRepository
            .transition(next.id, QueueStatus.approaching);
      }
      await widget.queueRepository.transition(next.id, QueueStatus.called);
    } on QueueFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _startBreak(QueueService service) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Start break · ${service.name}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                  'Students in this queue will be notified. Their timer pauses during the break.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              for (final value in const [10, 15, 30, 60])
                ListTile(
                  title: Text('$value minutes'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (minutes == null) return;
    try {
      await widget.queueRepository
          .startBreak(service.id, duration: Duration(minutes: minutes));
    } on QueueFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _endBreak(QueueService service) async {
    try {
      await widget.queueRepository.endBreak(service.id);
    } on QueueFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _complete(QueueEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete this service?'),
        content:
            Text('Mark ${entry.tokenCode} as completed and advance the queue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Complete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.queueRepository
          .transition(entry.id, QueueStatus.completed, staffId: widget.user.id);
      await _advanceQueue(entry);
    } on QueueFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _hold(QueueEntry entry) async {
    try {
      await widget.queueRepository.transition(entry.id, QueueStatus.onHold);
      await _advanceQueue(entry);
    } on QueueFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _advanceQueue(QueueEntry entry) async {
    final entries = await widget.queueRepository
        .watchQueue(entry.serviceId, departmentId: entry.departmentId)
        .first;
    if (mounted) await _callNext(entries);
  }

  Future<void> _resume(QueueEntry entry) async {
    try {
      await widget.queueRepository.transition(entry.id, QueueStatus.called);
    } on QueueFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _openScanner(QueueService service) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => QrScanScreen(
        departmentId: service.departmentId,
        serviceId: service.id,
        staffId: widget.user.id,
        queueRepository: widget.queueRepository,
      ),
    ));
  }

  Future<void> _openHistory(String departmentId) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HistoryScreen(
        userId: widget.user.id,
        departmentId: departmentId,
        forStudent: false,
        queueRepository: widget.queueRepository,
      ),
    ));
    if (mounted) setState(() => _selectedNavigation = 0);
  }

  @override
  Widget build(BuildContext context) {
    final departmentId = widget.user.departmentId;
    if (departmentId == null || departmentId.isEmpty) {
      return _DashboardError(
        title: 'No department assigned',
        message: 'Ask an administrator to assign a department to your account.',
        onSignOut: widget.authService.signOut,
      );
    }

    return StreamBuilder<List<QueueService>>(
      stream: widget.catalogService.watchDepartmentServices(departmentId),
      builder: (context, serviceSnapshot) {
        final services = serviceSnapshot.data ?? const <QueueService>[];
        QueueService? selected;
        for (final service in services) {
          if (service.id == _selectedServiceId) selected = service;
        }
        selected ??= services.isEmpty ? null : services.first;
        final selectedService = selected;
        if (_selectedServiceId != selectedService?.id &&
            selectedService != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _selectedServiceId = selectedService.id);
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Queue'),
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            actions: [
              if (selectedService != null)
                IconButton(
                  tooltip: selectedService.counterStatus == 'break'
                      ? 'End break'
                      : 'Start break',
                  onPressed: () => selectedService.counterStatus == 'break'
                      ? _endBreak(selectedService)
                      : _startBreak(selectedService),
                  icon: Icon(selectedService.counterStatus == 'break'
                      ? Icons.play_arrow_rounded
                      : Icons.free_breakfast_outlined),
                ),
              IconButton(
                tooltip: 'Log out',
                onPressed: widget.authService.signOut,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: serviceSnapshot.hasError
              ? _DashboardError(
                  title: 'Services unavailable',
                  message: 'Check your connection and retry.',
                  onSignOut: widget.authService.signOut,
                  onRetry: () => (context as Element).markNeedsBuild(),
                )
              : !serviceSnapshot.hasData
                  ? const ListSkeleton(count: 3)
                  : selectedService == null
                      ? const _DashboardEmpty(
                          title: 'No services configured',
                          message:
                              'An administrator needs to add a service for your department.',
                        )
                      : _QueueView(
                          service: selectedService,
                          services: services,
                          repository: widget.queueRepository,
                          onSelect: (service) =>
                              setState(() => _selectedServiceId = service.id),
                          onScan: () => _openScanner(selectedService),
                          onCallNext: _callNext,
                          onComplete: _complete,
                          onHold: _hold,
                          onResume: _resume,
                        ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedNavigation,
            onDestinationSelected: (index) async {
              setState(() => _selectedNavigation = index);
              if (index == 0) return;
              if (index == 1) {
                if (selectedService == null) {
                  setState(() => _selectedNavigation = 0);
                  return;
                }
                await _openScanner(selectedService);
                if (mounted) setState(() => _selectedNavigation = 0);
                return;
              }
              await _openHistory(departmentId);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups_rounded),
                label: 'Queue',
              ),
              NavigationDestination(
                icon: Icon(Icons.qr_code_scanner_outlined),
                selectedIcon: Icon(Icons.qr_code_scanner_rounded),
                label: 'Scan',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'History',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QueueView extends StatelessWidget {
  const _QueueView({
    required this.service,
    required this.services,
    required this.repository,
    required this.onSelect,
    required this.onScan,
    required this.onCallNext,
    required this.onComplete,
    required this.onHold,
    required this.onResume,
  });

  final QueueService service;
  final List<QueueService> services;
  final QueueServiceRepository repository;
  final ValueChanged<QueueService> onSelect;
  final VoidCallback onScan;
  final ValueChanged<List<QueueEntry>> onCallNext;
  final ValueChanged<QueueEntry> onComplete;
  final ValueChanged<QueueEntry> onHold;
  final ValueChanged<QueueEntry> onResume;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<QueueEntry>>(
        stream: repository.watchQueue(service.id,
            departmentId: service.departmentId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              title: 'Queue unavailable',
              onRetry: () => (context as Element).markNeedsBuild(),
            );
          }
          if (!snapshot.hasData) {
            return const ListSkeleton(count: 4);
          }
          final entries = snapshot.data!;
          final active = entries
              .where((entry) => entry.status.isActive)
              .toList(growable: false);
          QueueEntry? serving;
          for (final entry in active) {
            if (entry.status == QueueStatus.serving) serving = entry;
          }
          final waiting = active
              .where((entry) => {
                    QueueStatus.waiting,
                    QueueStatus.approaching,
                    QueueStatus.called,
                  }.contains(entry.status))
              .toList(growable: false);
          final held = active
              .where((entry) => entry.status == QueueStatus.onHold)
              .toList(growable: false);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  DropdownButtonFormField<QueueService>(
                    initialValue: service,
                    elevation: 0,
                    decoration:
                        const InputDecoration(labelText: 'Service counter'),
                    items: services
                        .map((item) => DropdownMenuItem(
                            value: item, child: Text(item.name)))
                        .toList(growable: false),
                    onChanged: (item) {
                      if (item != null) onSelect(item);
                    },
                  ),
                  if (service.counterStatus == 'break') ...[
                    const SizedBox(height: 12),
                    const _BreakBanner(),
                  ],
                  const SizedBox(height: 16),
                  if (serving != null)
                    _ServingCard(
                        entry: serving,
                        onComplete: () => onComplete(serving!),
                        onScan: onScan)
                  else
                    _NextCard(
                        count: waiting.length,
                        onCall: () => onCallNext(entries)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                          child: Text('Queue',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700))),
                      Text('${waiting.length} waiting',
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (waiting.isEmpty)
                    const _DashboardEmpty(
                        title: 'No one waiting',
                        message: 'The queue is clear for now.')
                  else
                    ...waiting.map((entry) => _QueueEntryTile(
                          entry: entry,
                          action: entry.status == QueueStatus.called
                              ? TextButton(
                                  onPressed: () => onHold(entry),
                                  child: const Text('Hold'))
                              : null,
                        )),
                  if (held.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('On hold · ${held.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...held.map((entry) => _QueueEntryTile(
                          entry: entry,
                          action: TextButton(
                              onPressed: () => onResume(entry),
                              child: const Text('Resume')),
                        )),
                  ],
                ],
              ),
            ),
          );
        },
      );
}

class _ServingCard extends StatelessWidget {
  const _ServingCard(
      {required this.entry, required this.onComplete, required this.onScan});

  final QueueEntry entry;
  final VoidCallback onComplete;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Now serving',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(entry.tokenCode,
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          Text(entry.studentFirstName,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onComplete,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Complete service'),
            ),
          ),
          TextButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan next token')),
        ]),
      );
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.count, required this.onCall});

  final int count;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.support_agent_outlined,
              color: AppColors.red, size: 32),
          const SizedBox(width: 12),
          Expanded(
              child: Text(count == 0
                  ? 'Queue is clear'
                  : '$count waiting in this queue')),
          FilledButton(
              onPressed: count == 0 ? null : onCall,
              child: const Text('Call next')),
        ]),
      );
}

class _QueueEntryTile extends StatelessWidget {
  const _QueueEntryTile({required this.entry, this.action});

  final QueueEntry entry;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          title: Text(entry.tokenCode,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.studentFirstName),
              const SizedBox(height: 4),
              StatusChip(status: entry.status),
            ],
          ),
          trailing: action,
          isThreeLine: true,
        ),
      );
}

class _BreakBanner extends StatelessWidget {
  const _BreakBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(10)),
        child: const Row(children: [
          Icon(Icons.pause_circle_outline_rounded, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
              child: Text('Counter on break. Queue timers are paused.',
                  style: TextStyle(color: AppColors.warning))),
        ]),
      );
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.queue_outlined, color: AppColors.red, size: 40),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError(
      {required this.title,
      required this.message,
      required this.onSignOut,
      this.onRetry});

  final String title;
  final String message;
  final Future<void> Function() onSignOut;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              TextButton(onPressed: onSignOut, child: const Text('Log out')),
            ]),
          ),
        ),
      );
}
