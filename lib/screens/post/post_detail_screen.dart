import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
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
import '../../models/comment.dart';
import '../../models/post.dart';
import '../post/create_post_screen.dart';
import '../profile/user_profile_screen.dart';

String _dayLabel(int days) => days == 1 ? 'ден' : 'дена';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    appStore.fetchCommentsForPost(widget.postId);
  }

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

  Future<void> _editPost(Post post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreatePostScreen(editingPost: post)),
    );
  }

  Future<void> _deletePost(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Избриши објава?'),
        content: const Text('Ова не може да се врати.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Откажи'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Избриши'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await appStore.deletePost(post.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _editComment(Comment comment) async {
    final controller = TextEditingController(text: comment.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Уреди коментар'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Откажи'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Зачувај'),
          ),
        ],
      ),
    );
    if (newText == null || newText.trim().isEmpty) return;
    final error = await appStore.updateComment(
      postId: comment.postId,
      commentId: comment.id,
      text: newText,
    );
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Избриши коментар?'),
        content: const Text('Ова не може да се врати.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Откажи'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Избриши'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await appStore.deleteComment(
      postId: comment.postId,
      commentId: comment.id,
    );
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final post = appStore.postById(widget.postId);
        if (post == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Објава')),
            body: const Center(child: Text('Објавата не е пронајдена.')),
          );
        }
        final author = appStore.userById(post.authorId);
        final comments = appStore.commentsForPost(post.id);
        final currentUserId = appStore.currentUserId;
        final liked = currentUserId != null && post.likedByUser(currentUserId);
        final isOwnPost = currentUserId != null && post.authorId == currentUserId;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Објава'),
            actions: [
              if (isOwnPost)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editPost(post);
                    if (value == 'delete') _deletePost(post);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Уреди')),
                    PopupMenuItem(value: 'delete', child: Text('Избриши')),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => UserProfileScreen(userId: post.authorId)),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(user: author, radius: 20),
                              const SizedBox(width: AppSpacing.sm),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(author.name, style: AppTypography.titleSmall),
                                  Text(timeAgo(post.createdAt), style: AppTypography.caption),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
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
                    const SizedBox(height: AppSpacing.sm),
                    if (post.type == PostType.quit && post.streakDays > 0)
                      _StreakBadgeDetail(days: post.streakDays)
                    else if (post.type != PostType.quit && post.durationDays > 0)
                      _DurationBadgeDetail(days: post.durationDays),
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
                      ...comments.map((c) => CommentTile(
                            comment: c,
                            onEdit: c.authorId == currentUserId
                                ? () => _editComment(c)
                                : null,
                            onDelete: c.authorId == currentUserId
                                ? () => _deleteComment(c)
                                : null,
                          )),
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
          ),
        );
      },
    );
  }
}

class _StreakBadgeDetail extends StatelessWidget {
  final int days;
  const _StreakBadgeDetail({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.quit.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            '$days ${_dayLabel(days)} streak',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.quit),
          ),
        ],
      ),
    );
  }
}

class _DurationBadgeDetail extends StatelessWidget {
  final int days;
  const _DurationBadgeDetail({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.achievement.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 12, color: AppColors.achievement),
          const SizedBox(width: 4),
          Text(
            '$days ${_dayLabel(days)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.achievement),
          ),
        ],
      ),
    );
  }
}
