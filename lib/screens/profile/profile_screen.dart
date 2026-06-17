import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/post_card.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/app_store.dart';
import '../auth/login_screen.dart';
import '../post/post_detail_screen.dart';
import 'edit_profile_screen.dart';

/// Екран за кориснички профил — преглед на лични податоци + сопствени објави.
///
/// UI flow: Profile -> "Уреди профил" -> EditProfileScreen -> (зачувај) -> Profile
///          Profile -> тап на објава -> PostDetailScreen
///          Profile -> "Одјави се" -> LoginScreen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final user = appStore.currentUser;
        if (user == null) return const SizedBox.shrink();
        final posts = appStore.postsByUser(user.id);
        final friendsCount = appStore.friendsOf(user.id).length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Профил'),
            actions: [
              IconButton(
                tooltip: 'Одјави се',
                icon: const Icon(AppIcons.logout),
                onPressed: () async {
                  await appStore.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
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
                        _StatBlock(label: 'Објави', value: posts.length),
                        const SizedBox(width: AppSpacing.xxl),
                        _StatBlock(label: 'Пријатели', value: friendsCount),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      icon: const Icon(AppIcons.edit, size: 18),
                      label: const Text('Уреди профил'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Text('Мои објави', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.md),
              if (posts.isEmpty)
                const EmptyState(
                  icon: AppIcons.feed,
                  title: 'Сè уште немаш објави',
                  subtitle: 'Сподели го твоето прво постигнување или откажување.',
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
