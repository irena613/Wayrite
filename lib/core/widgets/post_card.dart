import 'package:flutter/material.dart';
import '../../data/app_store.dart';
import '../../models/post.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'like_button.dart';
import 'post_type_badge.dart';
import 'user_avatar.dart';

/// Дизајн систем — картичка за објава, користена во Feed и во Профил
/// (листа на сопствени објави). Тапнување отвора детален преглед со
/// коментари (`onTap`).
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    final author = appStore.userById(post.authorId);
    final currentUserId = appStore.currentUserId;
    final liked = currentUserId != null && post.likedByUser(currentUserId);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(user: author, radius: 18),
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
              const SizedBox(height: AppSpacing.md),
              Text(post.title, style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                post.description,
                style: AppTypography.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(AppIcons.calendar, size: 14, color: AppTypography.bodySmall.color),
                  const SizedBox(width: 4),
                  Text(
                    post.endDate != null
                        ? '${formatDate(post.startDate)} – ${formatDate(post.endDate!)}'
                        : 'од ${formatDate(post.startDate)}',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg + AppSpacing.sm),
              Row(
                children: [
                  LikeButton(liked: liked, count: post.likeCount, onTap: onLikeTap),
                  const SizedBox(width: AppSpacing.lg),
                  Icon(AppIcons.comment, size: 18, color: AppTypography.bodySmall.color),
                  const SizedBox(width: 6),
                  Text('${post.commentCount}', style: AppTypography.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
