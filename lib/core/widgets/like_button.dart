import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Дизајн систем — копче за реакција (like) со бројач, користено и во
/// Feed картичките и во детален преглед на објава.
class LikeButton extends StatelessWidget {
  final bool liked;
  final int count;
  final VoidCallback onTap;

  const LikeButton({super.key, required this.liked, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? AppIcons.like : AppIcons.likeOutline,
              size: 20,
              color: liked ? AppColors.like : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: liked ? AppColors.like : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
