import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Број на денови од startDate до endDate (или до денес ако е тековна).
  int get durationDays {
    final end = endDate ?? DateTime.now();
    final days = end.difference(startDate).inDays;
    return days < 0 ? 0 : days;
  }

  /// Streak денови — значајно само за Quit објави.
  int get streakDays => type == PostType.quit ? durationDays : 0;

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: d['authorId'] as String,
      type: d['type'] == 'quit' ? PostType.quit : PostType.achievement,
      title: d['title'] as String,
      description: d['description'] as String,
      startDate: (d['startDate'] as Timestamp).toDate(),
      endDate: d['endDate'] != null ? (d['endDate'] as Timestamp).toDate() : null,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      likedBy: Set<String>.from(d['likedBy'] as List? ?? []),
      commentIds: List<String>.from(d['commentIds'] as List? ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'authorId': authorId,
    'type': type.name,
    'title': title,
    'description': description,
    'startDate': Timestamp.fromDate(startDate),
    if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
    'createdAt': Timestamp.fromDate(createdAt),
    'likedBy': likedBy.toList(),
    'commentIds': commentIds,
  };
}
