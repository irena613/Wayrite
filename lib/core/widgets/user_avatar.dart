import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../theme/app_colors.dart';

/// Дизајн систем — avatar. Без вистински слики (за wireframe ниво) —
/// прикажува иницијал на корисникот на боја генерирана од неговото id,
/// конзистентно секаде каде што се прикажува тој корисник.
class UserAvatar extends StatelessWidget {
  final AppUser user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.avatarColorFor(user.id);
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}
