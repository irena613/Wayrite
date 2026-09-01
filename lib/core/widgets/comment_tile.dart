import 'package:flutter/material.dart';
import '../../data/app_store.dart';
import '../../models/comment.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'user_avatar.dart';


class CommentTile extends StatelessWidget {
  final Comment comment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CommentTile({
    super.key,
    required this.comment,
    this.onEdit,
    this.onDelete,
  });

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
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => [
                if (onEdit != null)
                  const PopupMenuItem(value: 'edit', child: Text('Уреди')),
                if (onDelete != null)
                  const PopupMenuItem(value: 'delete', child: Text('Избриши')),
              ],
            ),
        ],
      ),
    );
  }
}
