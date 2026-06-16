import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'user_avatar.dart';

/// Дизајн систем — ред со корисник, користен во пребарување, листа на
/// пријатели и барања за пријателство. `trailing` носи копче специфично
/// за контекстот (Додај / Чека / Прифати+Одбиј / Пријатели).
class UserListTile extends StatelessWidget {
  final AppUser user;
  final Widget trailing;
  final VoidCallback? onTap;

  const UserListTile({super.key, required this.user, required this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            UserAvatar(user: user, radius: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: AppTypography.titleSmall),
                  Text('@${user.username}', style: AppTypography.bodySmall),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
