import 'package:cloud_firestore/cloud_firestore.dart';

/// Тип на нотификација. Секој тип одговара на еден настан кој (после
/// поврзување со Firebase Cloud Messaging) се испраќа и како push нотификација.
enum NotificationType { like, comment, friendRequest, friendAccept }

class NotificationItem {
  final String id;
  final String recipientId; // на кој корисник му е наменета нотификацијата
  final NotificationType type;
  final String actorId; // корисник кој предизвикал нотификацијата
  final String? postId; // релевантно за like/comment
  final DateTime createdAt;
  bool read;

  NotificationItem({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.actorId,
    this.postId,
    required this.createdAt,
    this.read = false,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NotificationItem(
      id: doc.id,
      recipientId: d['recipientId'] as String,
      type: NotificationType.values.firstWhere(
        (t) => t.name == d['type'],
        orElse: () => NotificationType.like,
      ),
      actorId: d['actorId'] as String,
      postId: d['postId'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      read: d['read'] as bool? ?? false,
    );
  }
}
