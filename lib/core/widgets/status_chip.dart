import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../core/strings.dart';
import '../../models/queue_entry.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final QueueStatus status;

  @override
  Widget build(BuildContext context) {
    final (fill, foreground, icon) = switch (status) {
      QueueStatus.waiting => (
          AppColors.waitingFill,
          AppColors.waitingText,
          Icons.schedule_rounded
        ),
      QueueStatus.approaching || QueueStatus.called => (
          AppColors.approachingFill,
          AppColors.approachingText,
          Icons.notifications_active_rounded,
        ),
      QueueStatus.serving => (
          AppColors.servingFill,
          AppColors.servingText,
          Icons.support_agent_rounded,
        ),
      QueueStatus.onHold => (
          AppColors.onHoldFill,
          AppColors.onHoldText,
          Icons.pause_circle_rounded,
        ),
      QueueStatus.completed => (
          AppColors.completedFill,
          AppColors.completedText,
          Icons.check_circle_rounded,
        ),
      QueueStatus.cancelled => (
          AppColors.cancelledFill,
          AppColors.cancelledText,
          Icons.cancel_rounded,
        ),
      QueueStatus.expired => (
          AppColors.expiredFill,
          AppColors.expiredText,
          Icons.timer_off_rounded,
        ),
    };

    return Semantics(
      label: '${status.label} status',
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(status.label,
              style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

String statusLabelForCopy(QueueStatus status) => switch (status) {
      QueueStatus.waiting => UniQueueStrings.statusWaiting,
      QueueStatus.approaching ||
      QueueStatus.called =>
        UniQueueStrings.statusApproaching,
      QueueStatus.serving => UniQueueStrings.statusServing,
      QueueStatus.onHold => UniQueueStrings.statusOnHold,
      QueueStatus.completed => UniQueueStrings.statusCompleted,
      QueueStatus.cancelled => UniQueueStrings.statusCancelled,
      QueueStatus.expired => UniQueueStrings.statusExpired,
    };
