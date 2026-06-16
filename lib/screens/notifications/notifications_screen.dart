import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/notification_tile.dart';
import '../../data/app_store.dart';
import '../../models/notification_item.dart';
import '../post/post_detail_screen.dart';
import '../search/search_screen.dart';

/// Екран со нотификации (like, коментар, барање/прифаќање за пријателство).
///
/// UI flow: Notifications -> тап на ставка ->
///            - like/comment -> PostDetailScreen на соодветната објава
///            - friendRequest/friendAccept -> SearchScreen (за да одговори
///              на барањето или да го види новиот пријател)
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Нотификации'),
        actions: [
          ListenableBuilder(
            listenable: appStore,
            builder: (context, _) {
              if (appStore.unreadNotificationCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: appStore.markAllNotificationsRead,
                child: const Text('Означи сѐ'),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: appStore,
        builder: (context, _) {
          final notifications = appStore.notificationsForCurrentUser;
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: AppIcons.notifications,
              title: 'Нема нотификации',
              subtitle: 'Тука ќе се појавуваат лајкови, коментари и барања за пријателство.',
            );
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationTile(
                notification: notification,
                onTap: () {
                  appStore.markNotificationRead(notification.id);
                  if (notification.postId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(postId: notification.postId!),
                      ),
                    );
                  } else if (notification.type == NotificationType.friendRequest ||
                      notification.type == NotificationType.friendAccept) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
