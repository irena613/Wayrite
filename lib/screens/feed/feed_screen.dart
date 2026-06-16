import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/post_card.dart';
import '../../data/app_store.dart';
import '../post/post_detail_screen.dart';

/// Feed екран со хронолошки приказ на објави (најнови прво).
///
/// UI flow: Feed -> тап на објава -> PostDetail (коментари + лајкови)
///          Feed -> повлечи надолу -> освежување
///          Feed -> FAB (+) во HomeShell -> CreatePost
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Тимски')),
      body: ListenableBuilder(
        listenable: appStore,
        builder: (context, _) {
          final posts = appStore.feedPosts;
          if (posts.isEmpty) {
            return const EmptyState(
              icon: AppIcons.feed,
              title: 'Нема објави сè уште',
              subtitle: 'Биди прв што ќе сподели постигнување или откажување.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 400));
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final post = posts[index];
                return PostCard(
                  post: post,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id)),
                  ),
                  onLikeTap: () => appStore.toggleLike(post.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
