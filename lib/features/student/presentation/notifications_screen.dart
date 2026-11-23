import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_colors.dart';
import '../../../core/widgets/flat_states.dart';
import '../../../models/app_notification.dart';
import '../../../services/notification_service.dart';
import '../../../services/queue_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen(
      {required this.userId, required this.queueRepository, super.key});

  final String userId;
  final QueueServiceRepository queueRepository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Stream<List<AppNotification>> _notifications;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() =>
      _notifications = widget.queueRepository.watchNotifications(widget.userId);

  void _retry() => setState(_bind);

  Future<void> _enablePush() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Get queue alerts'),
        content: const Text(
            'UniQueue can notify you when you are next, when your turn starts, and if the counter pauses.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable alerts')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final enabled = await context
        .read<NotificationService>()
        .requestPermissionAndRegister(widget.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled
            ? 'Queue alerts enabled.'
            : 'Alerts are unavailable. Check device permissions and try again.'),
      ),
    );
  }

  Future<void> _markRead(AppNotification notification) async {
    try {
      await widget.queueRepository.markNotificationRead(notification.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not mark this alert as read. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alerts')),
        body: StreamBuilder<List<AppNotification>>(
          stream: _notifications,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(title: 'Alerts unavailable', onRetry: _retry);
            }
            if (!snapshot.hasData) return const ListSkeleton(count: 4);
            final alerts = snapshot.data!;
            if (alerts.isEmpty) {
              return EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No alerts yet',
                message: 'Queue updates will appear here.',
                action: OutlinedButton.icon(
                  onPressed: _enablePush,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Enable push alerts'),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  constraints: const BoxConstraints(minHeight: 64),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Expanded(
                        child: Text('Get a heads-up when your queue changes.')),
                    TextButton(
                        onPressed: _enablePush, child: const Text('Enable')),
                  ]),
                ),
                ...alerts.map((alert) {
                  final time = alert.createdAt;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: alert.isRead
                          ? AppColors.surface
                          : AppColors.primarySoft,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        minVerticalPadding: 12,
                        leading: Icon(
                          alert.isRead
                              ? Icons.notifications_none_rounded
                              : Icons.notifications_active_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(alert.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(alert.message),
                        trailing: time == null
                            ? null
                            : Text(
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
                        onTap: alert.isRead ? null : () => _markRead(alert),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      );
}
