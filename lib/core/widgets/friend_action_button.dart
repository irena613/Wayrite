import 'package:flutter/material.dart';
import '../../data/app_store.dart';
import '../../models/relationship_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Дизајн систем — копче/акција за пријателство спрема статусот на врската
/// со дадениот корисник (Додај / Чека / Прифати+Одбиј / Пријатели). Издвоено
/// од `SearchScreen` за да се користи и на `UserProfileScreen`/`FriendsListScreen`.
/// Претпоставува дека родителот е веќе `ListenableBuilder(listenable: appStore)`.
class FriendActionButton extends StatelessWidget {
  final String userId;

  const FriendActionButton({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final status = appStore.relationshipWith(userId);
    switch (status) {
      case RelationshipStatus.none:
        return OutlinedButton.icon(
          icon: const Icon(AppIcons.friendAdd, size: 16),
          label: const Text('Додај'),
          onPressed: () => appStore.sendFriendRequest(userId),
        );
      case RelationshipStatus.requestSent:
        return OutlinedButton.icon(
          icon: const Icon(AppIcons.friendPending, size: 16),
          label: const Text('Чека'),
          onPressed: () => appStore.cancelFriendRequest(userId),
        );
      case RelationshipStatus.requestReceived:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Прифати',
              icon: const Icon(AppIcons.friendAccept, color: AppColors.success),
              onPressed: () => appStore.acceptFriendRequest(userId),
            ),
            IconButton(
              tooltip: 'Одбиј',
              icon: const Icon(AppIcons.friendDecline, color: AppColors.error),
              onPressed: () => appStore.declineFriendRequest(userId),
            ),
          ],
        );
      case RelationshipStatus.friends:
        return ActionChip(
          avatar: const Icon(AppIcons.friends, size: 16, color: AppColors.primaryDark),
          label: const Text('Пријатели'),
          onPressed: () => _confirmUnfriend(context, userId),
        );
    }
  }

  Future<void> _confirmUnfriend(BuildContext context, String userId) async {
    final user = appStore.userById(userId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отпријателување'),
        content: Text('Дали сакаш да го отстраниш ${user.name} од пријатели?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Откажи'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Отстрани', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await appStore.unfriend(userId);
    }
  }
}
