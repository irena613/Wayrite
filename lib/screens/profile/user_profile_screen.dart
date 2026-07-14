import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/friend_action_button.dart';
import '../../core/widgets/post_card.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/app_store.dart';
import '../../models/post.dart';
import '../../models/relationship_status.dart';
import '../post/post_detail_screen.dart';
import 'friends_list_screen.dart';

/// Профил на друг корисник (не тековниот најавен) — податоци + објави,
/// видливи само ако сме пријатели (согласно Firestore правилата).
///
/// UI flow: Search/FriendsList -> тап на ред -> UserProfileScreen
///          UserProfileScreen -> "Пријатели" -> FriendsListScreen
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  List<Post>? _posts;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void didUpdateWidget(covariant UserProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _posts = null);
    final isSelf = widget.userId == appStore.currentUserId;
    final isFriend =
        appStore.relationshipWith(widget.userId) == RelationshipStatus.friends;
    if (!isSelf && !isFriend) {
      setState(() => _posts = []);
      return;
    }
    final posts = await appStore.fetchPostsForUser(widget.userId);
    if (!mounted) return;
    setState(() => _posts = posts);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final user = appStore.userById(widget.userId);
        final isSelf = widget.userId == appStore.currentUserId;
        final isFriend =
            appStore.relationshipWith(widget.userId) == RelationshipStatus.friends;
        final friendsCount = appStore.friendsOf(widget.userId).length;
        final posts = _posts;

        return Scaffold(
          appBar: AppBar(title: Text(user.name)),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: Column(
                  children: [
                    UserAvatar(user: user, radius: 40),
                    const SizedBox(height: AppSpacing.md),
                    Text(user.name, style: AppTypography.titleLarge),
                    Text('@${user.username}', style: AppTypography.bodySmall),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        user.bio,
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StatBlock(label: 'Објави', value: posts?.length ?? 0),
                        const SizedBox(width: AppSpacing.xxl),
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FriendsListScreen(userId: widget.userId),
                            ),
                          ),
                          child: _StatBlock(label: 'Пријатели', value: friendsCount),
                        ),
                      ],
                    ),
                    if (!isSelf) ...[
                      const SizedBox(height: AppSpacing.lg),
                      FriendActionButton(userId: widget.userId),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Text('Објави', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.md),
              if (posts == null)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!isSelf && !isFriend)
                const EmptyState(
                  icon: AppIcons.friends,
                  title: 'Само пријателите можат да ги видат објавите',
                  subtitle: 'Стани пријател за да видиш што споделил/а.',
                )
              else if (posts.isEmpty)
                const EmptyState(
                  icon: AppIcons.feed,
                  title: 'Сè уште нема објави',
                )
              else
                ...posts.map(
                  (post) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: PostCard(
                      post: post,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id)),
                      ),
                      onLikeTap: () => appStore.toggleLike(post.id),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final int value;

  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: AppTypography.titleLarge),
        Text(label, style: AppTypography.bodySmall),
      ],
    );
  }
}
