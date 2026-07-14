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
  List<String> friendIds;

  AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.bio = '',
    List<String>? friendIds,
  }) : friendIds = friendIds ?? [];

  AppUser copyWith({
    String? name,
    String? username,
    String? email,
    String? bio,
    List<String>? friendIds,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      friendIds: friendIds ?? this.friendIds,
    );
  }
}
