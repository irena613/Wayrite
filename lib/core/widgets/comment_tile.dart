import 'package:flutter/material.dart';
import '../../data/app_store.dart';
import '../../models/comment.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'user_avatar.dart';

/// Дизајн систем — ред со коментар во детален преглед на објава.
class CommentTile extends StatelessWidget {
  final Comment comment;

  const CommentTile({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    final author = appStore.userById(comment.authorId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(user: author, radius: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F6),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(author.name, style: AppTypography.label),
                      const SizedBox(width: AppSpacing.sm),
                      Text(timeAgo(comment.createdAt), style: AppTypography.caption),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(comment.text, style: AppTypography.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
