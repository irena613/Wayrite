/// Модел за коментар на објава.
class Comment {
  final String id;
  final String postId;
  final String authorId;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.text,
    required this.createdAt,
  });
}
