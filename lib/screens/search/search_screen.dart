import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/user_list_tile.dart';
import '../../data/app_store.dart';
import '../../models/relationship_status.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пребарување')),
      // TextField is outside ListenableBuilder so that typing (setState) and
      // store notifications don't both rebuild the same subtree simultaneously,
      // which caused the 'child == _child' framework assertion.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Пребарај по име или корисничко име...',
                prefixIcon: Icon(AppIcons.search),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: appStore,
              builder: (context, _) {
                final results = appStore.searchUsers(_query);
                final incoming = appStore.incomingRequestUsers();
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  children: [
                    if (_query.isEmpty) ...[
                      if (incoming.isNotEmpty) ...[
                        Text('Барања за пријателство', style: AppTypography.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        ...incoming.map(
                          (u) => UserListTile(
                            key: ValueKey('req_${u.id}'),
                            user: u,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Прифати',
                                  icon: const Icon(AppIcons.friendAccept, color: AppColors.success),
                                  onPressed: () => appStore.acceptFriendRequest(u.id),
                                ),
                                IconButton(
                                  tooltip: 'Одбиј',
                                  icon: const Icon(AppIcons.friendDecline, color: AppColors.error),
                                  onPressed: () => appStore.declineFriendRequest(u.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xxl),
                          child: EmptyState(
                            icon: AppIcons.search,
                            title: 'Пребарај пријатели',
                            subtitle: 'Внеси име или корисничко име за да започнеш.',
                          ),
                        ),
                    ] else if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xxl),
                        child: EmptyState(
                          icon: AppIcons.search,
                          title: 'Нема резултати',
                        ),
                      )
                    else
                      ...results.map(
                        (u) => UserListTile(
                          key: ValueKey(u.id),
                          user: u,
                          trailing: _actionFor(u.id),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionFor(String userId) {
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
        return const Chip(
          avatar: Icon(AppIcons.friends, size: 16, color: AppColors.primaryDark),
          label: Text('Пријатели'),
        );
    }
  }
}
