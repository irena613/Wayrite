import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/post_card.dart';
import '../../data/app_store.dart';
import '../post/post_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load first page on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appStore.loadFeed(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      appStore.loadFeed();
    }
  }

  Future<void> _onRefresh() => appStore.loadFeed(refresh: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Тимски')),
      body: ListenableBuilder(
        listenable: appStore,
        builder: (context, _) {
          // Only real Firestore posts are shown. The in-memory demo posts
          // (p1–p5) are not backed by Firestore, so liking/commenting on them
          // is rejected by security rules and never fires the Cloud Function
          // triggers. Empty/loading states below handle the no-posts case.
          final posts = appStore.firestorePosts;

          // Error state — only show if no posts to display at all
          if (appStore.feedError != null && posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                  const SizedBox(height: AppSpacing.md),
                  Text(appStore.feedError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(
                    onPressed: () => appStore.loadFeed(refresh: true),
                    child: const Text('Обиди се повторно'),
                  ),
                ],
              ),
            );
          }

          // Initial loading state — only show if no posts to display yet
          if (appStore.feedLoading && posts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (posts.isEmpty) {
            return const EmptyState(
              icon: AppIcons.feed,
              title: 'Нема објави сè уште',
              subtitle: 'Биди прв што ќе сподели постигнување или откажување.',
            );
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: posts.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                if (index == posts.length) {
                  if (appStore.feedLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!appStore.hasMoreFeed) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                        child: Text('Нема повеќе објави',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }

                final post = posts[index];
                return PostCard(
                  post: post,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => PostDetailScreen(postId: post.id)),
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
