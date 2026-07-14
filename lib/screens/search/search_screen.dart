import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/friend_action_button.dart';
import '../../core/widgets/user_list_tile.dart';
import '../../data/app_store.dart';
import '../profile/user_profile_screen.dart';

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
                            trailing: FriendActionButton(userId: u.id),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => UserProfileScreen(userId: u.id)),
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
                          trailing: FriendActionButton(userId: u.id),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => UserProfileScreen(userId: u.id)),
                          ),
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
}
