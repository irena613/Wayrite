import 'package:flutter/material.dart';
import '../../data/app_store.dart';
import '../../models/notification_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'user_avatar.dart';

/// Дизајн систем — ред во листата со нотификации. Непрочитаните имаат
/// благо обоена позадина и точка-индикатор.
class NotificationTile extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const NotificationTile({super.key, required this.notification, required this.onTap});

  String get _message {
    final actor = appStore.userById(notification.actorId);
    switch (notification.type) {
      case NotificationType.like:
        return '${actor.name} реагираше на твоја објава';
      case NotificationType.comment:
        return '${actor.name} коментираше на твоја објава';
      case NotificationType.friendRequest:
        return '${actor.name} ти испрати барање за пријателство';
      case NotificationType.friendAccept:
        return '${actor.name} го прифати твоето барање за пријателство';
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = appStore.userById(notification.actorId);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.read ? Colors.transparent : AppColors.primaryLight.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(user: actor, radius: 20),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.forNotification(notification.type),
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_message, style: AppTypography.bodyMedium),
                  const SizedBox(height: 2),
                  Text(timeAgo(notification.createdAt), style: AppTypography.caption),
                ],
              ),
            ),
            if (!notification.read)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
