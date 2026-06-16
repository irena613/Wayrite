import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/comment_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/like_button.dart';
import '../../core/widgets/post_type_badge.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/app_store.dart';

/// Детален преглед на објава — UI за коментари и реакции (like).
///
/// UI flow: Feed/Profile -> тап на објава -> PostDetail
///          PostDetail -> внес коментар + "Испрати" -> коментарот се
///          додава во листата веднаш (хронолошки), автор на објавата
///          добива нотификација.
class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    appStore.addComment(widget.postId, text);
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Објава')),
      body: ListenableBuilder(
        listenable: appStore,
        builder: (context, _) {
          final post = appStore.feedPosts.firstWhere((p) => p.id == widget.postId);
          final author = appStore.userById(post.authorId);
          final comments = appStore.commentsForPost(post.id);
          final currentUserId = appStore.currentUserId;
          final liked = currentUserId != null && post.likedByUser(currentUserId);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Row(
                      children: [
                        UserAvatar(user: author, radius: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(author.name, style: AppTypography.titleSmall),
                              Text(timeAgo(post.createdAt), style: AppTypography.caption),
                            ],
                          ),
                        ),
                        PostTypeBadge(type: post.type),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(post.title, style: AppTypography.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(post.description, style: AppTypography.bodyLarge),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Icon(AppIcons.calendar, size: 14, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Text(
                          post.endDate != null
                              ? '${formatDate(post.startDate)} – ${formatDate(post.endDate!)}'
                              : 'од ${formatDate(post.startDate)}',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    LikeButton(
                      liked: liked,
                      count: post.likeCount,
                      onTap: () => appStore.toggleLike(post.id),
                    ),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Коментари (${comments.length})', style: AppTypography.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    if (comments.isEmpty)
                      const EmptyState(icon: AppIcons.comment, title: 'Сè уште нема коментари')
                    else
                      ...comments.map((c) => CommentTile(comment: c)),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(hintText: 'Напиши коментар...'),
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filled(
                        icon: const Icon(AppIcons.send),
                        onPressed: _sendComment,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
