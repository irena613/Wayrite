import 'package:flutter/material.dart';
import '../../data/app_store.dart';
import '../../models/post.dart';
import '../theme/app_colors.dart';
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
              const SizedBox(height: AppSpacing.sm),
              if (post.type == PostType.quit && post.streakDays > 0)
                _StreakBadge(days: post.streakDays)
              else if (post.type != PostType.quit && post.durationDays > 0)
                _DurationBadge(days: post.durationDays),
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

class _StreakBadge extends StatelessWidget {
  final int days;
  const _StreakBadge({required this.days});

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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.quit,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  final int days;
  const _DurationBadge({required this.days});

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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.achievement,
            ),
          ),
        ],
      ),
    );
  }
}

String _dayLabel(int days) {
  if (days == 1) return 'ден';
  if (days >= 2 && days <= 4) return 'дена';
  return 'дена';
}
