import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../../../core/widgets/flat_states.dart';
import '../../../features/auth/data/auth_service.dart';
import '../../../models/app_user.dart';
import '../../../models/department.dart';
import '../../../models/queue_entry.dart';
import '../../../models/queue_service.dart';
import '../../../services/catalog_service.dart';
import '../../../services/queue_service.dart';
import 'active_token_screen.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({
    required this.department,
    required this.user,
    required this.authService,
    required this.catalogService,
    required this.queueRepository,
    super.key,
  });

  final Department department;
  final AppUser user;
  final AuthService authService;
  final CatalogService catalogService;
  final QueueServiceRepository queueRepository;

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  String _search = '';
  String? _joiningServiceId;

  Future<void> _join(QueueService service) async {
    setState(() => _joiningServiceId = service.id);
    try {
      final entry = await widget.queueRepository.createToken(
        studentId: widget.user.id,
        studentFirstName: widget.user.name.split(' ').first,
        serviceId: service.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ActiveTokenScreen(
          entry: entry,
          queueRepository: widget.queueRepository,
          authService: widget.authService,
          averageServiceTime: service.averageServiceTime,
        ),
      ));
    } on QueueFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Could not join the queue. Check your connection and retry.')),
      );
    } finally {
      if (mounted) setState(() => _joiningServiceId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Choose a service'),
          leading: IconButton(
            tooltip: 'Back to departments',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: StreamBuilder<List<QueueService>>(
          stream: widget.catalogService
              .watchDepartmentServices(widget.department.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _SelectionState(
                icon: Icons.wifi_off_rounded,
                title: 'Services unavailable',
                detail: 'Check your connection and try again.',
                action: FilledButton.tonalIcon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              );
            }
            if (!snapshot.hasData) return const ListSkeleton(count: 4);
            final allServices = snapshot.data!;
            final services = allServices
                .where((service) =>
                    service.name.toLowerCase().contains(_search.toLowerCase()))
                .toList(growable: false);
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    border: Border.all(color: AppColors.primaryDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.apartment_rounded,
                            color: AppColors.surface, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SERVICE DESK',
                                style: TextStyle(
                                    color: AppColors.primarySoft,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(widget.department.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.surface,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            const Text(
                                'Join a live queue without waiting in line',
                                style: TextStyle(
                                    color: AppColors.primarySoft,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: InputDecoration(
                      hintText: 'Search services',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => setState(() => _search = ''),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Available services',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      Text('${services.length} available',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: services.isEmpty
                      ? _SelectionState(
                          icon: _search.isEmpty
                              ? Icons.support_agent_rounded
                              : Icons.search_off_rounded,
                          title: _search.isEmpty
                              ? 'Services are being set up'
                              : 'No matching service',
                          detail: _search.isEmpty
                              ? 'An admin visit prepares a starter service for each department. Refresh the list or check back shortly.'
                              : 'Try another service name.',
                          action: _search.isEmpty
                              ? TextButton.icon(
                                  onPressed: () => setState(() {}),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Refresh services'),
                                )
                              : null,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          itemCount: services.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _ServiceCard(
                            service: services[index],
                            queueRepository: widget.queueRepository,
                            isJoining: _joiningServiceId == services[index].id,
                            onJoin: () => _join(services[index]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      );
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.queueRepository,
    required this.isJoining,
    required this.onJoin,
  });

  final QueueService service;
  final QueueServiceRepository queueRepository;
  final bool isJoining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(service.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700))),
                _CounterStatus(status: service.counterStatus),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: queueRepository.watchPublicQueue(service.id),
              builder: (context, snapshot) {
                final waiting = snapshot.data
                        ?.where((entry) => const {
                              QueueStatus.waiting,
                              QueueStatus.approaching,
                              QueueStatus.called,
                            }.contains(QueueStatusLabel.parse(
                                entry['status'] as String?)))
                        .length ??
                    0;
                if (snapshot.hasError) {
                  return const Text('Queue count unavailable',
                      style: TextStyle(color: AppColors.textSecondary));
                }
                if (!snapshot.hasData) {
                  return const Text('Loading queue…',
                      style: TextStyle(color: AppColors.textSecondary));
                }
                return Text(
                  '$waiting waiting · about ${(waiting * service.averageServiceTime)} min',
                  style: const TextStyle(color: AppColors.textSecondary),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                onPressed: service.acceptsTokens && !isJoining ? onJoin : null,
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: isJoining
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.surface),
                      )
                    : Text(service.acceptsTokens ? 'Get Token' : 'Unavailable'),
              ),
            ),
          ],
        ),
      );
}

class _CounterStatus extends StatelessWidget {
  const _CounterStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'open' => 'Open',
      'break' => 'On break',
      _ => 'Closed',
    };
    final color = status == 'open'
        ? AppColors.success
        : status == 'break'
            ? AppColors.warning
            : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
            status == 'open'
                ? Icons.check_circle_outline
                : Icons.pause_circle_outline,
            size: 16,
            color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _SelectionState extends StatelessWidget {
  const _SelectionState(
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
              Icon(icon, color: AppColors.red, size: 40),
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
