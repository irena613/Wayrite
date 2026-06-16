import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';

/// Дизајн систем — мал бедж кој означува дали објавата е Achievement или Quit.
class PostTypeBadge extends StatelessWidget {
  final PostType type;

  const PostTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.forPostType(type), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
