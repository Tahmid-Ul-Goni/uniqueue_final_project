import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../../../core/widgets/flat_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../models/queue_history.dart';
import '../../../models/queue_entry.dart';
import '../../../models/queue_service.dart' as service_model;
import '../../../services/queue_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.userId,
    required this.queueRepository,
    this.departmentId,
    this.forStudent = true,
    super.key,
  });

  final String userId;
  final String? departmentId;
  final bool forStudent;
  final QueueServiceRepository queueRepository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Stream<List<QueueHistory>> _history;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() => _history = widget.queueRepository.watchHistory(
        forStudent: widget.forStudent,
        userId: widget.userId,
        departmentId: widget.departmentId,
      );

  void _retry() => setState(_bind);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: StreamBuilder<List<QueueHistory>>(
          stream: _history,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                title: 'History unavailable',
                onRetry: _retry,
              );
            }
            if (!snapshot.hasData) return const ListSkeleton(count: 4);
            final entries = snapshot.data!;
            if (entries.isEmpty) {
              return const EmptyState(
                icon: Icons.history_rounded,
                title: 'No history yet',
                message:
                    'Completed, cancelled and expired tokens will appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final status = switch (entry.outcome) {
                  'cancelled' => QueueStatus.cancelled,
                  'expired' => QueueStatus.expired,
                  _ => QueueStatus.completed,
                };
                final date = entry.occurredAt;
                return Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.confirmation_number_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(entry.tokenCode,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            date == null
                                ? 'Queue visit'
                                : '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                            style:
                                const TextStyle(color: AppColors.textSecondary),
                          ),
                          StreamBuilder<service_model.QueueService?>(
                            stream: widget.queueRepository
                                .watchService(entry.serviceId),
                            builder: (context, serviceSnapshot) => Text(
                              serviceSnapshot.data?.name ?? 'Queue service',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(status: status),
                  ]),
                );
              },
            );
          },
        ),
      );
}
