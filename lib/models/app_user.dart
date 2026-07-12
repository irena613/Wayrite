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

  // Нова листа за чување на ID-ата на пријателите
  List<String> friendsIds;

  AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.bio = '',
    this.friendsIds = const [], // Стандардно е празна листа ако нема пријатели
  });

  // Методи за менаџирање пријателства директно во моделот
  void addFriend(String friendId) {
    if (!friendsIds.contains(friendId)) {
      friendsIds.add(friendId);
    }
  }

  void removeFriend(String friendId) {
    friendsIds.remove(friendId);
  }

  bool isFriendWith(String friendId) {
    return friendsIds.contains(friendId);
  }

  AppUser copyWith({
    String? name,
    String? username,
    String? email,
    String? bio,
    List<String>? friendsIds,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      friendsIds: friendsIds ?? this.friendsIds,
    );
  }
}