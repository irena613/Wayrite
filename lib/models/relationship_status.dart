import 'relationship_status.dart'; // Оваа линија ја поврзува листата со статуси

/// Модел за корисник.
///
/// Кога ќе се поврзе Firebase Authentication + Firestore, овој модел
/// останува непроменет — само `MockUserRepository` (data/mock_data_store.dart)
/// се заменува со имплементација која чита/пишува во колекцијата `users`.
class AppUser {
  final String id;
  String name;
  String username;
  String email;
  String bio;

  // Менаџирање со пријателства и барања
  List<String> friendsIds;
  List<String> sentRequestsIds;     // Корисници на кои ЈАС им имам пратено барање
  List<String> receivedRequestsIds; // Корисници кои МЕНЕ ми пратиле барање

  AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.bio = '',
    this.friendsIds = const [],
    this.sentRequestsIds = const [],
    this.receivedRequestsIds = const [],
  });

  // Функција која автоматски кажува каков е статусот со некој друг корисник
  RelationshipStatus getRelationshipWith(String otherUserId) {
    if (friendsIds.contains(otherUserId)) {
      return RelationshipStatus.friends;
    }
    if (sentRequestsIds.contains(otherUserId)) {
      return RelationshipStatus.requestSent;
    }
    if (receivedRequestsIds.contains(otherUserId)) {
      return RelationshipStatus.requestReceived;
    }
    return RelationshipStatus.none;
  }

  // Логика за праќање барање
  void sendFriendRequest(String toUserId) {
    if (!sentRequestsIds.contains(toUserId) && !friendsIds.contains(toUserId)) {
      sentRequestsIds.add(toUserId);
    }
  }

  // Логика за прифаќање барање
  void acceptFriendRequest(String fromUserId) {
    receivedRequestsIds.remove(fromUserId);
    if (!friendsIds.contains(fromUserId)) {
      friendsIds.add(fromUserId);
    }
  }

  // Логика за одбивање барање
  void declineFriendRequest(String fromUserId) {
    receivedRequestsIds.remove(fromUserId);
  }

  // Логика за бришење од пријатели
  void removeFriend(String friendId) {
    friendsIds.remove(friendId);
  }

  AppUser copyWith({
    String? name,
    String? username,
    String? email,
    String? bio,
    List<String>? friendsIds,
    List<String>? sentRequestsIds,
    List<String>? receivedRequestsIds,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      friendsIds: friendsIds ?? this.friendsIds,
      sentRequestsIds: sentRequestsIds ?? this.sentRequestsIds,
      receivedRequestsIds: receivedRequestsIds ?? this.receivedRequestsIds,
    );
  }
}