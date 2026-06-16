import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/comment.dart';
import '../models/notification_item.dart';
import '../models/post.dart';
import '../models/relationship_status.dart';

/// In-memory "backend" за апликацијата.
///
/// Намерно е изграден со истите операции што ќе ги треба и реалниот
/// Firebase backend (login/register, create post, like, comment,
/// friend requests, notifications), за подоцна лесно да се замени со
/// repository класи кои зборуваат со FirebaseAuth / Firestore / Functions
/// — види docs/FIREBASE_SETUP.md.
class MockDataStore extends ChangeNotifier {
  MockDataStore() {
    _seedDemoData();
  }

  final List<AppUser> _users = [];
  final Map<String, String> _passwordsByEmail = {}; // email -> password
  final List<Post> _posts = [];
  final List<Comment> _comments = [];
  final List<NotificationItem> _notifications = [];

  // userId -> set на пријатели (симетрично)
  final Map<String, Set<String>> _friends = {};
  // targetUserId -> set на userId кои му испратиле барање за пријателство
  final Map<String, Set<String>> _incomingRequests = {};

  String? currentUserId;

  AppUser? get currentUser =>
      currentUserId == null ? null : userById(currentUserId!);

  bool get isLoggedIn => currentUserId != null;

  // ---------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------

  /// Враќа порака за грешка, или null ако успешно се најавил.
  String? login(String email, String password) {
    final normalizedEmail = email.trim().toLowerCase();
    final storedPassword = _passwordsByEmail[normalizedEmail];
    if (storedPassword == null) {
      return 'Не постои корисник со овој е-маил.';
    }
    if (storedPassword != password) {
      return 'Погрешна лозинка.';
    }
    final user = _users.firstWhere((u) => u.email == normalizedEmail);
    currentUserId = user.id;
    notifyListeners();
    return null;
  }

  /// Враќа порака за грешка, или null ако успешно се регистрирал.
  String? register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUsername = username.trim().toLowerCase();
    if (name.trim().isEmpty || username.trim().isEmpty) {
      return 'Внеси име и корисничко име.';
    }
    if (_passwordsByEmail.containsKey(normalizedEmail)) {
      return 'Веќе постои корисник со овој е-маил.';
    }
    if (_users.any((u) => u.username.toLowerCase() == normalizedUsername)) {
      return 'Корисничкото име е веќе зафатено.';
    }
    if (password.length < 6) {
      return 'Лозинката мора да има најмалку 6 карактери.';
    }
    final user = AppUser(
      id: 'u${_users.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      username: normalizedUsername,
      email: normalizedEmail,
    );
    _users.add(user);
    _passwordsByEmail[normalizedEmail] = password;
    currentUserId = user.id;
    notifyListeners();
    return null;
  }

  /// Брз начин да се прегледа апликацијата без рачно регистрирање.
  void loginAsDemoUser() {
    currentUserId = _users.first.id;
    notifyListeners();
  }

  void logout() {
    currentUserId = null;
    notifyListeners();
  }

  void updateProfile({String? name, String? username, String? bio}) {
    final user = currentUser;
    if (user == null) return;
    user.name = name ?? user.name;
    user.username = username ?? user.username;
    user.bio = bio ?? user.bio;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Users / search / friends
  // ---------------------------------------------------------------------

  AppUser userById(String id) => _users.firstWhere((u) => u.id == id);

  List<AppUser> searchUsers(String query) {
    final q = query.trim().toLowerCase();
    return _users.where((u) {
      if (u.id == currentUserId) return false;
      if (q.isEmpty) return false;
      return u.name.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q);
    }).toList();
  }

  List<AppUser> friendsOf(String userId) {
    final ids = _friends[userId] ?? <String>{};
    return ids.map(userById).toList();
  }

  List<AppUser> incomingRequestUsers() {
    if (currentUserId == null) return [];
    final ids = _incomingRequests[currentUserId!] ?? <String>{};
    return ids.map(userById).toList();
  }

  RelationshipStatus relationshipWith(String otherUserId) {
    if (currentUserId == null) return RelationshipStatus.none;
    if (_friends[currentUserId!]?.contains(otherUserId) ?? false) {
      return RelationshipStatus.friends;
    }
    if (_incomingRequests[currentUserId!]?.contains(otherUserId) ?? false) {
      return RelationshipStatus.requestReceived;
    }
    if (_incomingRequests[otherUserId]?.contains(currentUserId!) ?? false) {
      return RelationshipStatus.requestSent;
    }
    return RelationshipStatus.none;
  }

  void sendFriendRequest(String targetUserId) {
    if (currentUserId == null) return;
    _incomingRequests.putIfAbsent(targetUserId, () => <String>{});
    _incomingRequests[targetUserId]!.add(currentUserId!);
    _addNotification(
      forUserId: targetUserId,
      type: NotificationType.friendRequest,
      actorId: currentUserId!,
    );
    notifyListeners();
  }

  void cancelFriendRequest(String targetUserId) {
    if (currentUserId == null) return;
    _incomingRequests[targetUserId]?.remove(currentUserId!);
    notifyListeners();
  }

  void acceptFriendRequest(String requesterId) {
    if (currentUserId == null) return;
    _incomingRequests[currentUserId!]?.remove(requesterId);
    _friends.putIfAbsent(currentUserId!, () => <String>{}).add(requesterId);
    _friends.putIfAbsent(requesterId, () => <String>{}).add(currentUserId!);
    _addNotification(
      forUserId: requesterId,
      type: NotificationType.friendAccept,
      actorId: currentUserId!,
    );
    notifyListeners();
  }

  void declineFriendRequest(String requesterId) {
    if (currentUserId == null) return;
    _incomingRequests[currentUserId!]?.remove(requesterId);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Posts / feed
  // ---------------------------------------------------------------------

  List<Post> get feedPosts {
    final sorted = [..._posts];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  List<Post> postsByUser(String userId) {
    return feedPosts.where((p) => p.authorId == userId).toList();
  }

  Post createPost({
    required PostType type,
    required String title,
    required String description,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final post = Post(
      id: 'p${_posts.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
      authorId: currentUserId!,
      type: type,
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.now(),
    );
    _posts.add(post);
    notifyListeners();
    return post;
  }

  void toggleLike(String postId) {
    if (currentUserId == null) return;
    final post = _posts.firstWhere((p) => p.id == postId);
    final liking = !post.likedByUser(currentUserId!);
    if (liking) {
      post.likedBy.add(currentUserId!);
      if (post.authorId != currentUserId) {
        _addNotification(
          forUserId: post.authorId,
          type: NotificationType.like,
          actorId: currentUserId!,
          postId: post.id,
        );
      }
    } else {
      post.likedBy.remove(currentUserId!);
    }
    notifyListeners();
  }

  List<Comment> commentsForPost(String postId) {
    final list = _comments.where((c) => c.postId == postId).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Comment addComment(String postId, String text) {
    final comment = Comment(
      id: 'c${_comments.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      authorId: currentUserId!,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    _comments.add(comment);
    final post = _posts.firstWhere((p) => p.id == postId);
    post.commentIds.add(comment.id);
    if (post.authorId != currentUserId) {
      _addNotification(
        forUserId: post.authorId,
        type: NotificationType.comment,
        actorId: currentUserId!,
        postId: post.id,
      );
    }
    notifyListeners();
    return comment;
  }

  // ---------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------

  List<NotificationItem> get notificationsForCurrentUser {
    if (currentUserId == null) return [];
    final list =
        _notifications.where((n) => n.recipientId == currentUserId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int get unreadNotificationCount =>
      notificationsForCurrentUser.where((n) => !n.read).length;

  void markNotificationRead(String id) {
    final n = _notifications.firstWhere((n) => n.id == id);
    n.read = true;
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in notificationsForCurrentUser) {
      n.read = true;
    }
    notifyListeners();
  }

  void _addNotification({
    required String forUserId,
    required NotificationType type,
    required String actorId,
    String? postId,
  }) {
    _notifications.add(
      NotificationItem(
        id: 'n${_notifications.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
        recipientId: forUserId,
        type: type,
        actorId: actorId,
        postId: postId,
        createdAt: DateTime.now(),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Demo seed data — само за преглед на UI flow-то без вистински backend.
  // ---------------------------------------------------------------------

  void _seedDemoData() {
    final marija = AppUser(
      id: 'u1',
      name: 'Марија Стојановска',
      username: 'marija',
      email: 'marija@demo.mk',
      bio: 'Се трудам секој ден да бидам подобра верзија од себе 🌱',
    );
    final igor = AppUser(
      id: 'u2',
      name: 'Игор Петровски',
      username: 'igor.p',
      email: 'igor@demo.mk',
      bio: 'Без цигари од јуни 2026.',
    );
    final ana = AppUser(
      id: 'u3',
      name: 'Ана Илиева',
      username: 'ana_ilieva',
      email: 'ana@demo.mk',
      bio: 'Читам, тренирам, учам.',
    );
    final stefan = AppUser(
      id: 'u4',
      name: 'Стефан Николов',
      username: 'stefan.n',
      email: 'stefan@demo.mk',
      bio: '',
    );

    _users.addAll([marija, igor, ana, stefan]);
    for (final u in _users) {
      _passwordsByEmail[u.email] = 'demo123';
    }

    _friends[marija.id] = {igor.id};
    _friends[igor.id] = {marija.id};

    _incomingRequests[marija.id] = {ana.id}; // Ана сака да се спријателат

    final now = DateTime.now();

    final p1 = Post(
      id: 'p1',
      authorId: marija.id,
      type: PostType.achievement,
      title: '30 дена редовно тренирање',
      description:
          'Цел месец без прескокнување тренинг! Чувствувам разлика и во енергијата и во дисциплината.',
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now,
      createdAt: now.subtract(const Duration(hours: 5)),
    );
    final p2 = Post(
      id: 'p2',
      authorId: igor.id,
      type: PostType.quit,
      title: 'Без цигари 10 дена',
      description: 'Најтешките се првите дена, но иде полека.',
      startDate: now.subtract(const Duration(days: 10)),
      createdAt: now.subtract(const Duration(hours: 14)),
    );
    final p3 = Post(
      id: 'p3',
      authorId: ana.id,
      type: PostType.achievement,
      title: 'Прочитав 5 книги во еден месец',
      description: 'Си поставив цел да читам по 20-тина страници дневно.',
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now.subtract(const Duration(days: 1)),
      createdAt: now.subtract(const Duration(days: 1, hours: 3)),
    );
    final p4 = Post(
      id: 'p4',
      authorId: marija.id,
      type: PostType.quit,
      title: 'Без социјални мрежи по 22ч',
      description: 'Спијам подобро откако ги исклучувам нотификациите навечер.',
      startDate: now.subtract(const Duration(days: 4)),
      createdAt: now.subtract(const Duration(days: 3)),
    );

    _posts.addAll([p1, p2, p3, p4]);

    p1.likedBy.add(igor.id);
    p2.likedBy.addAll({marija.id, ana.id});

    final c1 = Comment(
      id: 'c1',
      postId: p1.id,
      authorId: igor.id,
      text: 'Браво другар, продолжи така! 💪',
      createdAt: now.subtract(const Duration(hours: 4)),
    );
    final c2 = Comment(
      id: 'c2',
      postId: p2.id,
      authorId: marija.id,
      text: 'Гордa сум на тебе, секој ден е победа 👏',
      createdAt: now.subtract(const Duration(hours: 10)),
    );
    _comments.addAll([c1, c2]);
    p1.commentIds.add(c1.id);
    p2.commentIds.add(c2.id);

    _notifications.addAll([
      NotificationItem(
        id: 'n1',
        recipientId: marija.id,
        type: NotificationType.like,
        actorId: igor.id,
        postId: p1.id,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      NotificationItem(
        id: 'n2',
        recipientId: marija.id,
        type: NotificationType.comment,
        actorId: igor.id,
        postId: p1.id,
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      NotificationItem(
        id: 'n3',
        recipientId: marija.id,
        type: NotificationType.friendRequest,
        actorId: ana.id,
        createdAt: now.subtract(const Duration(days: 1)),
        read: true,
      ),
    ]);
  }
}
