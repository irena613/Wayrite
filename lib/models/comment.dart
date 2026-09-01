import 'package:cloud_firestore/cloud_firestore.dart';

/// Модел за коментар на објава.
class Comment {
  final String id;
  final String postId;
  final String authorId;
  String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.text,
    required this.createdAt,
  });

  /// `postId` не е поле во документот (се темели на патеката
  /// `posts/{postId}/comments/{commentId}`), затоа се пренесува одделно.
  factory Comment.fromFirestore(DocumentSnapshot doc, String postId) {
    final d = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      postId: postId,
      authorId: d['authorId'] as String,
      text: d['text'] as String,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }
}
