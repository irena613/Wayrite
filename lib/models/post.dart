import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Тип на објава: постигнување (Achievement) или откажување од навика (Quit).
enum PostType { achievement, quit }

extension PostTypeX on PostType {
  String get label {
    switch (this) {
      case PostType.achievement:
        return 'Постигнување';
      case PostType.quit:
        return 'Откажување';
    }
  }

  Color get color {
    switch (this) {
      case PostType.achievement:
        return AppColors.achievement;
      case PostType.quit:
        return AppColors.quit;
    }
  }
}

/// Модел за објава. `startDate` е денот кога е започнато постигнувањето /
/// откажувањето, `endDate` е опционален (пр. „чист од 16.06.2026“).
class Post {
  final String id;
  final String authorId;
  final PostType type;
  String title;
  String description;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final Set<String> likedBy;
  final List<String> commentIds;

  Post({
    required this.id,
    required this.authorId,
    required this.type,
    required this.title,
    required this.description,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    Set<String>? likedBy,
    List<String>? commentIds,
  })  : likedBy = likedBy ?? <String>{},
        commentIds = commentIds ?? <String>[];

  int get likeCount => likedBy.length;
  int get commentCount => commentIds.length;

  bool likedByUser(String userId) => likedBy.contains(userId);
}
