import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/friend_action_button.dart';
import '../../core/widgets/user_list_tile.dart';
import '../../data/app_store.dart';
import 'user_profile_screen.dart';

/// Листа на пријатели на даден корисник (сопствени или туѓи — `users`
/// документите ги чита секој најавен корисник, па и пријателската листа
/// на некој друг е видлива).
///
/// UI flow: Profile/UserProfileScreen -> "Пријатели" -> FriendsListScreen
///          FriendsListScreen -> тап на ред -> UserProfileScreen
class FriendsListScreen extends StatefulWidget {
  final String userId;

  const FriendsListScreen({super.key, required this.userId});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  @override
  void initState() {
    super.initState();
    appStore.ensureFriendsLoaded(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пријатели')),
      body: ListenableBuilder(
        listenable: appStore,
        builder: (context, _) {
          final friends = appStore.friendsOf(widget.userId);
          if (friends.isEmpty) {
            return const EmptyState(
              icon: AppIcons.friends,
              title: 'Нема пријатели сè уште',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final friend = friends[index];
              final isSelf = friend.id == appStore.currentUserId;
              return UserListTile(
                user: friend,
                trailing: isSelf
                    ? const SizedBox.shrink()
                    : FriendActionButton(userId: friend.id),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => UserProfileScreen(userId: friend.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
