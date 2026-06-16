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
}
