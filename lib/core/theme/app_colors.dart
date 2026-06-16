import 'package:flutter/material.dart';

/// Дизајн систем — бои.
///
/// Сите бои во апликацијата треба да се повикуваат преку овие константи,
/// никогаш hard-coded Color(0x...) во екраните, за да остане UI-то конзистентно.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF5B6BF5);
  static const Color primaryDark = Color(0xFF3F4ED1);
  static const Color primaryLight = Color(0xFFE7E9FE);

  // Семантски бои за типот на објава
  static const Color achievement = Color(0xFF2EB872); // постигнување (зелено)
  static const Color quit = Color(0xFFFF7A59); // откажување од лоша навика (топло)

  // Неутрални / поврзани со текст и позадина
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF1A1B25);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFFAFB3BD);

  // Статус
  static const Color error = Color(0xFFE53E3E);
  static const Color success = Color(0xFF2EB872);
  static const Color like = Color(0xFFFF4D67);
  static const Color warning = Color(0xFFF5A623);

  // Палета за автоматски генерирани avatar бои (по индекс од userId.hashCode)
  static const List<Color> avatarPalette = [
    Color(0xFF5B6BF5),
    Color(0xFF2EB872),
    Color(0xFFFF7A59),
    Color(0xFFF5A623),
    Color(0xFF22B8CF),
    Color(0xFFE64980),
  ];

  static Color avatarColorFor(String seed) {
    final index = seed.hashCode.abs() % avatarPalette.length;
    return avatarPalette[index];
  }
}
