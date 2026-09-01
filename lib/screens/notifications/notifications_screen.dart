import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/notification_tile.dart';
import '../../data/app_store.dart';
import '../../models/notification_item.dart';
import '../post/post_detail_screen.dart';
import '../search/search_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Нотификации'),
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
              return Dismissible(
                key: ValueKey(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => appStore.deleteNotification(notification.id),
                child: NotificationTile(
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
