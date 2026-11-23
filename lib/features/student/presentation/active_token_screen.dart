import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/app_colors.dart';
import '../../../core/widgets/flat_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../features/auth/data/auth_service.dart';
import '../../../models/queue_entry.dart';
import '../../../models/queue_service.dart' as model;
import '../../../services/queue_service.dart';

class ActiveTokenScreen extends StatelessWidget {
  const ActiveTokenScreen({
    required this.entry,
    required this.queueRepository,
    required this.authService,
    this.averageServiceTime,
    super.key,
  });

  final QueueEntry entry;
  final QueueServiceRepository queueRepository;
  final AuthService authService;
  final int? averageServiceTime;

  Future<void> _cancel(BuildContext context, QueueEntry current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this token?'),
        content: const Text(
            'You will leave the queue and need to get a new token to rejoin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep token')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel token')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await queueRepository.transition(current.id, QueueStatus.cancelled);
      if (context.mounted) Navigator.pop(context);
    } on QueueFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Your token')),
        body: StreamBuilder<QueueEntry?>(
          stream: queueRepository.watchEntry(entry.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                title: 'Queue info may be outdated',
                onRetry: () => (context as Element).markNeedsBuild(),
              );
            }
            final current = snapshot.data;
            if (!snapshot.hasData) {
              return const ListSkeleton(count: 3);
            }
            if (current == null) {
              return const _InfoState(
                icon: Icons.error_outline_rounded,
                title: 'Token unavailable',
                detail: 'Go back and refresh your queue.',
              );
            }

            return StreamBuilder<QueuePosition>(
              stream:
                  queueRepository.watchPosition(current, averageServiceTime),
              builder: (context, positionSnapshot) {
                final canCancel = {
                  QueueStatus.waiting,
                  QueueStatus.approaching,
                  QueueStatus.onHold,
                }.contains(current.status);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  children: [
                    StreamBuilder<model.QueueService?>(
                      stream: queueRepository.watchService(current.serviceId),
                      builder: (context, serviceSnapshot) {
                        final service = serviceSnapshot.data;
                        if (service?.counterStatus != 'break') {
                          return const SizedBox.shrink();
                        }
                        final returnTime = service?.breakUntil;
                        final timeText = returnTime == null
                            ? ''
                            : ' until ${returnTime.hour.toString().padLeft(2, '0')}:${returnTime.minute.toString().padLeft(2, '0')}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _NoticeBanner(
                            icon: Icons.pause_circle_outline_rounded,
                            message:
                                'Counter on break$timeText. Your place is safe.',
                          ),
                        );
                      },
                    ),
                    Center(child: StatusChip(status: current.status)),
                    const SizedBox(height: 20),
                    if (current.status == QueueStatus.onHold)
                      _NoticeBanner(
                        icon: Icons.pause_circle_outline_rounded,
                        message: 'You’re on hold. Resume when you arrive.',
                        deadline: current.holdEndsAt,
                        deadlineLabel: 'Hold time left',
                        serviceId: current.serviceId,
                        queueRepository: queueRepository,
                        action: TextButton(
                          onPressed: () async {
                            try {
                              await queueRepository.transition(
                                  current.id, QueueStatus.called);
                            } on QueueFailure catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.message)));
                              }
                            }
                          },
                          child: const Text('I’m here · Resume'),
                        ),
                      )
                    else if (current.status == QueueStatus.called)
                      _NoticeBanner(
                        icon: Icons.notifications_active_outlined,
                        message:
                            'It’s your turn. Show this QR code at the counter.',
                        deadline: current.graceEndsAt,
                        deadlineLabel: 'Please arrive within',
                        serviceId: current.serviceId,
                        queueRepository: queueRepository,
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Semantics(
                            label: 'QR code for token ${current.tokenCode}',
                            child: QrImageView(
                              data: current.qrPayload,
                              size: 240,
                              backgroundColor: AppColors.surface,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            current.tokenCode,
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (positionSnapshot.hasError)
                      const Text('Position unavailable. Reconnect to update.',
                          textAlign: TextAlign.center)
                    else if (!positionSnapshot.hasData)
                      const FlatSkeleton(height: 88)
                    else
                      _PositionPanel(position: positionSnapshot.data!),
                    const SizedBox(height: 12),
                    Text(
                      'Last updated just now',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Need help?'),
                          content: const Text(
                              'Show your token code to the receptionist or ask them to check your queue status.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Got it'))
                          ],
                        ),
                      ),
                      icon: const Icon(Icons.help_outline_rounded),
                      label: const Text('Need help?'),
                    ),
                    if (canCancel) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _cancel(context, current),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error),
                        child: const Text('Cancel token'),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      );
}

class _PositionPanel extends StatelessWidget {
  const _PositionPanel({required this.position});

  final QueuePosition position;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Metric(value: '${position.position}', label: 'Position'),
            Container(width: 1, height: 42, color: AppColors.border),
            _Metric(
                value: 'About ${position.waitMinutes} min',
                label: 'Estimated wait'),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      );
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.icon,
    required this.message,
    this.action,
    this.deadline,
    this.deadlineLabel,
    this.serviceId,
    this.queueRepository,
  });

  final IconData icon;
  final String message;
  final Widget? action;
  final DateTime? deadline;
  final String? deadlineLabel;
  final String? serviceId;
  final QueueServiceRepository? queueRepository;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
            color: AppColors.redSoft, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, color: AppColors.redDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(color: AppColors.redDark)),
                if (deadline != null &&
                    deadlineLabel != null &&
                    serviceId != null &&
                    queueRepository != null)
                  _DeadlineText(
                    deadline: deadline!,
                    label: deadlineLabel!,
                    serviceId: serviceId!,
                    queueRepository: queueRepository!,
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ]),
      );
}

class _DeadlineText extends StatefulWidget {
  const _DeadlineText({
    required this.deadline,
    required this.label,
    required this.serviceId,
    required this.queueRepository,
  });

  final DateTime deadline;
  final String label;
  final String serviceId;
  final QueueServiceRepository queueRepository;

  @override
  State<_DeadlineText> createState() => _DeadlineTextState();
}

class _DeadlineTextState extends State<_DeadlineText> {
  Timer? _timer;
  late Stream<model.QueueService?> _serviceStream;

  @override
  void initState() {
    super.initState();
    _serviceStream = widget.queueRepository.watchService(widget.serviceId);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<model.QueueService?>(
      stream: _serviceStream,
      builder: (context, snapshot) {
        if (snapshot.data?.counterStatus == 'break') {
          return const Text(
            'Paused while the counter is on break',
            style: TextStyle(
                color: AppColors.redDark, fontWeight: FontWeight.w700),
          );
        }
        final seconds = widget.deadline
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 599999);
        final minutes = seconds ~/ 60;
        final secondsPart = (seconds % 60).toString().padLeft(2, '0');
        return Text(
          seconds == 0
              ? 'Time window ended'
              : '${widget.label}: $minutes:$secondsPart',
          style: const TextStyle(
            color: AppColors.redDark,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }
}

class _InfoState extends StatelessWidget {
  const _InfoState(
      {required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 42, color: AppColors.red),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 6),
            Text(detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
}
