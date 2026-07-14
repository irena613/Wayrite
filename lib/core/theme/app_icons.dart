import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../models/notification_item.dart';

/// Дизајн систем — мапирање на икони (Material Icons се веќе вклучени
/// преку `uses-material-design: true` во pubspec.yaml, нема потреба од
/// дополнителен icon font).
class AppIcons {
  AppIcons._();

  static const IconData feed = Icons.dynamic_feed_outlined;
  static const IconData search = Icons.search;
  static const IconData add = Icons.add_circle;
  static const IconData notifications = Icons.notifications_none_rounded;
  static const IconData notificationsActive = Icons.notifications_active_rounded;
  static const IconData profile = Icons.person_outline_rounded;

  static const IconData like = Icons.favorite;
  static const IconData likeOutline = Icons.favorite_border;
  static const IconData comment = Icons.mode_comment_outlined;
  static const IconData send = Icons.send_rounded;

  static const IconData friendAdd = Icons.person_add_alt_1_outlined;
  static const IconData friendPending = Icons.hourglass_top_rounded;
  static const IconData friendAccept = Icons.check_circle_outline;
  static const IconData friendDecline = Icons.close_rounded;
  static const IconData friends = Icons.people_alt_outlined;
  static const IconData friendRemove = Icons.person_remove_alt_1_outlined;

  static const IconData calendar = Icons.calendar_today_outlined;
  static const IconData edit = Icons.edit_outlined;
  static const IconData logout = Icons.logout_rounded;

  static IconData forPostType(PostType type) {
    switch (type) {
      case PostType.achievement:
        return Icons.emoji_events_rounded;
      case PostType.quit:
        return Icons.block_rounded;
    }
  }

  static IconData forNotification(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return like;
      case NotificationType.comment:
        return comment;
      case NotificationType.friendRequest:
        return friendAdd;
      case NotificationType.friendAccept:
        return friends;
    }
  }
}
