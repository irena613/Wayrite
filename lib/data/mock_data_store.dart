import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  bool _tokenRefreshListenerAttached = false;

  @override
  void dispose() {
    _stopListeningToCurrentUser();
    super.dispose();
  }

  final List<AppUser> _users = [];
  final Map<String, String> _passwordsByEmail = {}; // email -> password
  final List<Post> _posts = [];
  final List<Comment> _comments = [];
  final List<NotificationItem> _notifications = [];
  final List<NotificationItem> _firestoreNotifications = [];

  // Firestore feed state
  final List<Post> _firestorePosts = [];
  DocumentSnapshot? _lastFeedDoc;
  bool _hasMoreFeed = true;
  bool _feedLoading = false;
  String? _feedError;

  static const int _pageSize = 10;

  List<Post> get firestorePosts => List.unmodifiable(_firestorePosts);
  bool get feedLoading => _feedLoading;
  bool get hasMoreFeed => _hasMoreFeed;
  String? get feedError => _feedError;

  // Пријателски барања упатени ДО тековниот корисник (сѐ уште нерешени).
  final Set<String> _incomingRequestFromIds = {};
  // Пријателски барања што тековниот корисник ги ИСПРАТИЛ (сѐ уште нерешени).
  final Set<String> _outgoingRequestToIds = {};
  StreamSubscription<QuerySnapshot>? _incomingRequestsSub;
  StreamSubscription<QuerySnapshot>? _outgoingRequestsSub;
  StreamSubscription<DocumentSnapshot>? _currentUserDocSub;
  StreamSubscription<QuerySnapshot>? _notificationsSub;

  String? currentUserId;
  String? _fcmToken;

  AppUser? get currentUser =>
      currentUserId == null ? null : userById(currentUserId!);

  bool get isLoggedIn => currentUserId != null;

  // ---------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------

  /// Проверува дали постои активна Firebase сесија и ја враќа во appStore.
  Future<void> restoreSession() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    _upsertFirebaseUser(firebaseUser);
    currentUserId = firebaseUser.uid;
    _listenToCurrentUser();
    unawaited(_initFcm());
  }

  /// Враќа порака за грешка, или null ако успешно се најавил.
  Future<String?> login(String email, String password) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _upsertFirebaseUser(credential.user!);
      currentUserId = credential.user!.uid;
      _listenToCurrentUser();
      notifyListeners();
      unawaited(_initFcm());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    }
  }

  /// Враќа порака за грешка, или null ако успешно се регистрирал.
  Future<String?> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    if (name.trim().isEmpty || username.trim().isEmpty) {
      return 'Внеси име и корисничко име.';
    }
    if (_users.any((u) => u.username.toLowerCase() == username.trim().toLowerCase())) {
      return 'Корисничкото име е веќе зафатено.';
    }
    try {
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username.trim().toLowerCase())
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return 'Корисничкото име е веќе зафатено.';
    } catch (_) {}
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(name.trim());
      final user = AppUser(
        id: credential.user!.uid,
        name: name.trim(),
        username: username.trim().toLowerCase(),
        email: email.trim().toLowerCase(),
      );
      _users.add(user);
      currentUserId = credential.user!.uid;
      _listenToCurrentUser();

      // Save user profile to Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          'name': user.name,
          'username': user.username,
          'email': user.email,
          'bio': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      notifyListeners();
      unawaited(_initFcm());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    }
  }

  /// Брз начин да се прегледа апликацијата без рачно регистрирање.
  void loginAsDemoUser() {
    currentUserId = _users.first.id;
    notifyListeners();
  }

  Future<void> logout() async {
    if (_fcmToken != null) {
      await _unregisterToken(_fcmToken!);
      _fcmToken = null;
    }
    await FirebaseAuth.instance.signOut();
    _stopListeningToCurrentUser();
    currentUserId = null;
    notifyListeners();
  }

  void _upsertFirebaseUser(User firebaseUser) {
    if (_users.any((u) => u.id == firebaseUser.uid)) return;
    _users.add(AppUser(
      id: firebaseUser.uid,
      name: firebaseUser.displayName ?? firebaseUser.email!.split('@').first,
      username: firebaseUser.email!.split('@').first,
      email: firebaseUser.email!,
    ));
  }

  String _authError(String code) {
    return switch (code) {
      'user-not-found' || 'invalid-credential' || 'wrong-password' =>
        'Погрешен е-маил или лозинка.',
      'email-already-in-use' => 'Веќе постои корисник со овој е-маил.',
      'weak-password' => 'Лозинката мора да има најмалку 6 карактери.',
      'invalid-email' => 'Невалидна е-маил адреса.',
      'network-request-failed' => 'Нема интернет конекција.',
      _ => 'Се случи грешка. Обиди се повторно.',
    };
  }

  // ---------------------------------------------------------------------
  // FCM — управување со push-нотификациски токени
  // ---------------------------------------------------------------------

  /// Бара дозвола за нотификации и го регистрира FCM токенот на уредот.
  Future<void> _initFcm() async {
    try {
      // Слушај за освежување на FCM токенот (се случува ретко, но мора да
      // се регистрира новиот и да се отстрани стариот). Закачено овде (не во
      // конструкторот) за appStore да може безбедно да се конструира и пред
      // Firebase.initializeApp() да заврши — конструкторот се повикува на
      // првото читање на глобалниот `appStore`, кое може да се случи пред
      // Firebase да е подготвен (пр. во тестови).
      if (!_tokenRefreshListenerAttached) {
        _tokenRefreshListenerAttached = true;
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          if (_fcmToken != null && _fcmToken != newToken) {
            _unregisterToken(_fcmToken!);
          }
          _registerToken(newToken);
        });
      }
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } catch (_) {
      // FCM иницијализацијата не смее да ја урне апликацијата.
    }
  }

  /// Додава токен во `users/{uid}.fcmTokens` преку Cloud Function.
  Future<void> _registerToken(String token) async {
    if (currentUserId == null) return;
    try {
      _fcmToken = token;
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('registerFcmToken')
          .call(<String, dynamic>{'token': token});
    } catch (_) {}
  }

  /// Отстранува токен од `users/{uid}.fcmTokens` преку Cloud Function.
  Future<void> _unregisterToken(String token) async {
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('unregisterFcmToken')
          .call(<String, dynamic>{'token': token});
    } catch (_) {}
  }

  void updateProfile({String? name, String? username, String? bio}) {
    final user = currentUser;
    if (user == null) return;
    user.name = name ?? user.name;
    user.username = username ?? user.username;
    user.bio = bio ?? user.bio;

    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (username != null) 'username': username,
      if (bio != null) 'bio': bio,
    };
    if (updates.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update(updates)
          .catchError((_) {});
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Users / search / friends
  // ---------------------------------------------------------------------

  AppUser userById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return AppUser(id: id, name: 'Корисник', username: id, email: '');
    }
  }

  Post? postById(String id) {
    try {
      return _posts.firstWhere((p) => p.id == id);
    } catch (_) {}
    try {
      return _firestorePosts.firstWhere((p) => p.id == id);
    } catch (_) {}
    return null;
  }

  final Set<String> _pendingRemoteSearchQueries = {};

  /// Пребарува локално вчитани корисници веднаш (за responsive UI), и
  /// паралелно бара по точен `username` во Firestore за корисници што сѐ
  /// уште не се локално вчитани — потребно откако feed-от е ограничен само
  /// на пријатели, па нови корисници повеќе не се автоматски вчитуваат
  /// преку туѓи објави. Точен match (не prefix) - prefix-range query со
  /// invisible upper-bound character не работеше поуздано преку
  /// платформскиот канал на Android, па е избегнат.
  List<AppUser> searchUsers(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    unawaited(_searchUsersRemote(q));

    return _users.where((u) {
      if (u.id == currentUserId) return false;
      return u.name.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _searchUsersRemote(String query) async {
    if (_pendingRemoteSearchQueries.contains(query)) return;
    _pendingRemoteSearchQueries.add(query);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: query)
          .limit(10)
          .get();
      var changed = false;
      for (final doc in snapshot.docs) {
        if (_users.any((u) => u.id == doc.id)) continue;
        final d = doc.data();
        _users.add(AppUser(
          id: doc.id,
          name: d['name'] as String? ?? 'Корисник',
          username: d['username'] as String? ?? doc.id,
          email: d['email'] as String? ?? '',
          bio: d['bio'] as String? ?? '',
          friendIds: List<String>.from(d['friendIds'] as List? ?? []),
        ));
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (e) {
      debugPrint('searchUsers remote query failed: $e');
    } finally {
      _pendingRemoteSearchQueries.remove(query);
    }
  }

  /// Слуша во реално време за: (а) сопствениот `users` документ (име,
  /// bio, `friendIds`) и (б) пријателски барања упатени до/од тековниот
  /// корисник. Замена за поранешните in-memory `_friends`/`_incomingRequests`
  /// мапи — состојбата сега доаѓа директно од Firestore.
  void _listenToCurrentUser() {
    if (currentUserId == null) return;
    _currentUserDocSub?.cancel();
    _currentUserDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId!)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final d = doc.data()!;
      final user = userById(currentUserId!);
      user.name = d['name'] as String? ?? user.name;
      user.username = d['username'] as String? ?? user.username;
      user.bio = d['bio'] as String? ?? user.bio;
      user.friendIds = List<String>.from(d['friendIds'] as List? ?? []);
      notifyListeners();
    }, onError: (e) => debugPrint('currentUserDocSub error: $e'));

    // Слушателите за barawa го чистат demo seed-от (пр. лажното барање од
    // Ана) штом првиот снапшот пристигне. Ако снапшотот никогаш не пристигне
    // (пр. permission-denied од Firestore правилата), тој seed останува
    // засекогаш — затоа е важно грешките овде да не поминуваат тивко.
    _incomingRequestsSub?.cancel();
    _incomingRequestsSub = FirebaseFirestore.instance
        .collection('friendRequests')
        .where('toUserId', isEqualTo: currentUserId)
        .snapshots()
        .listen((snapshot) {
      _incomingRequestFromIds
        ..clear()
        ..addAll(snapshot.docs.map((d) => d['fromUserId'] as String));
      for (final id in _incomingRequestFromIds) {
        unawaited(_ensureUserLoaded(id));
      }
      notifyListeners();
    }, onError: (e) => debugPrint('incomingRequestsSub error: $e'));

    _outgoingRequestsSub?.cancel();
    _outgoingRequestsSub = FirebaseFirestore.instance
        .collection('friendRequests')
        .where('fromUserId', isEqualTo: currentUserId)
        .snapshots()
        .listen((snapshot) {
      _outgoingRequestToIds
        ..clear()
        ..addAll(snapshot.docs.map((d) => d['toUserId'] as String));
      notifyListeners();
    }, onError: (e) => debugPrint('outgoingRequestsSub error: $e'));

    // Реални нотификации (like/comment/friendRequest/friendAccept) —
    // запишани од Cloud Functions во `notifications` колекцијата.
    _notificationsSub?.cancel();
    _notificationsSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: currentUserId)
        .snapshots()
        .listen((snapshot) {
      _firestoreNotifications
        ..clear()
        ..addAll(snapshot.docs.map(NotificationItem.fromFirestore));
      for (final n in _firestoreNotifications) {
        unawaited(_ensureUserLoaded(n.actorId));
      }
      notifyListeners();
    }, onError: (e) => debugPrint('notificationsSub error: $e'));
  }

  void _stopListeningToCurrentUser() {
    _currentUserDocSub?.cancel();
    _incomingRequestsSub?.cancel();
    _outgoingRequestsSub?.cancel();
    _notificationsSub?.cancel();
    _currentUserDocSub = null;
    _incomingRequestsSub = null;
    _outgoingRequestsSub = null;
    _notificationsSub = null;
    _incomingRequestFromIds.clear();
    _outgoingRequestToIds.clear();
    _firestoreNotifications.clear();
  }

  List<AppUser> friendsOf(String userId) {
    return userById(userId).friendIds.map(userById).toList();
  }

  /// Ги вчитува во `_users` (ако не се веќе таму) сите пријатели на `userId`,
  /// за нивните имиња/username да се прикажат правилно во `FriendsListScreen`
  /// наместо placeholder "Корисник".
  Future<void> ensureFriendsLoaded(String userId) async {
    final ids = userById(userId).friendIds;
    for (final id in ids) {
      await _ensureUserLoaded(id);
    }
    notifyListeners();
  }

  List<AppUser> incomingRequestUsers() {
    return _incomingRequestFromIds.map(userById).toList();
  }

  RelationshipStatus relationshipWith(String otherUserId) {
    if (currentUserId == null) return RelationshipStatus.none;
    if (currentUser!.friendIds.contains(otherUserId)) {
      return RelationshipStatus.friends;
    }
    if (_incomingRequestFromIds.contains(otherUserId)) {
      return RelationshipStatus.requestReceived;
    }
    if (_outgoingRequestToIds.contains(otherUserId)) {
      return RelationshipStatus.requestSent;
    }
    return RelationshipStatus.none;
  }

  /// Испраќа барање за пријателство преку Cloud Function (`sendFriendRequest`)
  /// — таа атомски проверува дека не постои веќе пријателство/барање во која
  /// било насока. UI состојбата се освежува преку `_incomingRequestsSub` /
  /// `_outgoingRequestsSub`, не рачно овде.
  ///
  /// Враќа порака за грешка на македонски ако повикот не успее, инаку null.
  Future<String?> sendFriendRequest(String targetUserId) async {
    if (currentUserId == null) return null;
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('sendFriendRequest')
          .call(<String, dynamic>{'toUserId': targetUserId});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Се случи грешка. Обиди се повторно.';
    } catch (_) {
      return 'Нема интернет конекција.';
    }
  }

  Future<String?> cancelFriendRequest(String targetUserId) async {
    if (currentUserId == null) return null;
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('cancelFriendRequest')
          .call(<String, dynamic>{'toUserId': targetUserId});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Се случи грешка. Обиди се повторно.';
    } catch (_) {
      return 'Нема интернет конекција.';
    }
  }

  /// Прифаќа барање за пријателство преку Cloud Function
  /// (`acceptFriendRequest`) — атомски ги ажурира `friendIds` на двата
  /// корисника, што со обичен клиентски запис не е безбедно изводливо.
  Future<String?> acceptFriendRequest(String requesterId) async {
    if (currentUserId == null) return null;
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('acceptFriendRequest')
          .call(<String, dynamic>{'fromUserId': requesterId});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Се случи грешка. Обиди се повторно.';
    } catch (_) {
      return 'Нема интернет конекција.';
    }
  }

  Future<String?> declineFriendRequest(String requesterId) async {
    if (currentUserId == null) return null;
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('declineFriendRequest')
          .call(<String, dynamic>{'fromUserId': requesterId});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Се случи грешка. Обиди се повторно.';
    } catch (_) {
      return 'Нема интернет конекција.';
    }
  }

  Future<String?> unfriend(String otherUserId) async {
    if (currentUserId == null) return null;
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('unfriend')
          .call(<String, dynamic>{'otherUserId': otherUserId});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Се случи грешка. Обиди се повторно.';
    } catch (_) {
      return 'Нема интернет конекција.';
    }
  }

  // ---------------------------------------------------------------------
  // Posts / feed
  // ---------------------------------------------------------------------

  /// Директно вчитување на објавите на еден корисник (за `ProfileScreen`/
  /// `UserProfileScreen`), наместо потпирање на веќе-испагинираниот главен
  /// feed. Firestore правилата бараат `isSelfOrFriend(authorId)` — ако не сме
  /// пријатели, барањето паѓа со permission-denied и враќаме празна листа.
  /// Резултатите се спојуваат во `_firestorePosts` за `postById` (користен од
  /// `PostDetailScreen`) секогаш да може да ги најде, без разлика дали
  /// објавата дошла преку главниот feed или преку профил.
  Future<List<Post>> fetchPostsForUser(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      final posts = <Post>[];
      for (final doc in snapshot.docs) {
        try {
          posts.add(Post.fromFirestore(doc));
        } catch (_) {
          // Skip malformed post docs so one bad document can't sink the list.
        }
      }
      for (final post in posts) {
        final idx = _firestorePosts.indexWhere((p) => p.id == post.id);
        if (idx == -1) {
          _firestorePosts.add(post);
        } else {
          _firestorePosts[idx] = post;
        }
      }
      notifyListeners();
      return posts;
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------
  // Firestore feed — loading, pagination, refresh
  // ---------------------------------------------------------------------

  Future<void> loadFeed({bool refresh = false}) async {
    if (_feedLoading) return;
    if (refresh) {
      _firestorePosts.clear();
      _lastFeedDoc = null;
      _hasMoreFeed = true;
      _feedError = null;
    }
    if (!_hasMoreFeed) return;
    if (currentUserId == null) return;

    _feedLoading = true;
    _feedError = null;
    notifyListeners();

    try {
      // Posts are only readable by their author's friends (see
      // firestore.rules) — Firestore rejects an unconstrained query outright
      // rather than silently filtering it, so the feed must be scoped
      // client-side via `authorId in [...]`. `whereIn` caps at 30 values;
      // for now only the first 30 friends (by array order) are included.
      final authorIds = <String>[
        currentUserId!,
        ...currentUser!.friendIds.take(29),
      ];

      var query = FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', whereIn: authorIds)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      if (_lastFeedDoc != null) {
        query = query.startAfterDocument(_lastFeedDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMoreFeed = false;
      } else {
        _lastFeedDoc = snapshot.docs.last;
        // Parse each doc defensively — one malformed post must not sink the
        // whole feed. Skip and log bad docs so they can be fixed in Firestore.
        final newPosts = <Post>[];
        for (final doc in snapshot.docs) {
          try {
            newPosts.add(Post.fromFirestore(doc));
          } catch (_) {
            // Skip malformed post docs so one bad document can't sink the feed.
          }
        }
        _firestorePosts.addAll(newPosts);
        if (snapshot.docs.length < _pageSize) _hasMoreFeed = false;

        // Make sure authors are in _users
        for (final post in newPosts) {
          await _ensureUserLoaded(post.authorId);
        }
      }
    } catch (_) {
      _feedError = 'Не може да се вчитаат објавите. Провери го интернетот.';
    }

    _feedLoading = false;
    notifyListeners();
  }

  Future<void> _ensureUserLoaded(String userId) async {
    if (_users.any((u) => u.id == userId)) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        final d = doc.data()!;
        _users.add(AppUser(
          id: userId,
          name: d['name'] as String? ?? 'Корисник',
          username: d['username'] as String? ?? userId,
          email: d['email'] as String? ?? '',
          bio: d['bio'] as String? ?? '',
          friendIds: List<String>.from(d['friendIds'] as List? ?? []),
        ));
      }
    } catch (_) {}
  }

  Future<Post> createPost({
    required PostType type,
    required String title,
    required String description,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    // Pre-generate the Firestore doc ref so _posts and _firestorePosts share the same ID.
    final docRef = FirebaseFirestore.instance.collection('posts').doc();
    final post = Post(
      id: docRef.id,
      authorId: currentUserId!,
      type: type,
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
    );
    _posts.add(post);
    _firestorePosts.insert(0, post);

    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('createPostValidated')
          .call(<String, dynamic>{
        'postId': docRef.id,
        'type': type.name,
        'title': title,
        'description': description,
        'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'invalid-argument' || e.code == 'unauthenticated') {
        // Server rejected the input — roll back optimistic state and surface error.
        _posts.remove(post);
        _firestorePosts.remove(post);
        notifyListeners();
        rethrow;
      }
      // Function not yet deployed or unavailable — fall back to direct write.
      await docRef.set(post.toFirestore()).catchError((_) {});
    } catch (_) {
      // Non-Functions error — fall back to direct write.
      await docRef.set(post.toFirestore()).catchError((_) {});
    }

    notifyListeners();
    return post;
  }

  void toggleLike(String postId) {
    if (currentUserId == null) return;
    final post = postById(postId);
    if (post == null) return;
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

    FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'likedBy': post.likedBy.toList(),
    }).catchError((_) {});

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
    final post = postById(postId);
    if (post == null) return comment;
    post.commentIds.add(comment.id);

    FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'commentIds': post.commentIds,
    }).catchError((_) {});

    // Write comment sub-document — required for onCommentCreated trigger.
    FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(comment.id)
        .set({
      'authorId': comment.authorId,
      'text': comment.text,
      'createdAt': Timestamp.fromDate(comment.createdAt),
    }).catchError((_) {});

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
    final list = [
      ..._notifications.where((n) => n.recipientId == currentUserId),
      ..._firestoreNotifications,
    ];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int get unreadNotificationCount =>
      notificationsForCurrentUser.where((n) => !n.read).length;

  void markNotificationRead(String id) {
    final remote = _firestoreNotifications.where((n) => n.id == id);
    if (remote.isNotEmpty) {
      remote.first.read = true;
      unawaited(FirebaseFirestore.instance
          .collection('notifications')
          .doc(id)
          .update({'read': true}));
      notifyListeners();
      return;
    }
    final n = _notifications.firstWhere((n) => n.id == id);
    n.read = true;
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in notificationsForCurrentUser) {
      if (n.read) continue;
      n.read = true;
      if (_firestoreNotifications.contains(n)) {
        unawaited(FirebaseFirestore.instance
            .collection('notifications')
            .doc(n.id)
            .update({'read': true}));
      }
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

    marija.friendIds.add(igor.id);
    igor.friendIds.add(marija.id);

    // Демо-корисникот е секогаш marija (loginAsDemoUser), па директно
    // сеедуваме "нерешено" барање наместо преку Firestore listener.
    _incomingRequestFromIds.add(ana.id); // Ана сака да се спријателат

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
