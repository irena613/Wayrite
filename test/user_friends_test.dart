import 'package:flutter_test/flutter_test.dart';
import 'package:timski/models/app_user.dart';
import 'package:timski/models/relationship_status.dart';

// Оваа датотека претходно тестираше локална, in-memory логика за
// пријателства директно на AppUser (friendsIds/sentRequestsIds/
// receivedRequestsIds + методи на моделот). Таа логика е заменета со
// Firestore/Cloud Functions имплементација (friendIds на AppUser,
// MockDataStore.relationshipWith/sendFriendRequest/...), па старите
// тестови повеќе не се применливи. Оставено како минимален placeholder.
void main() {
  test('AppUser.friendIds стандардно е празна листа', () {
    final user = AppUser(
      id: '1',
      name: 'Marija',
      username: 'marija_n',
      email: 'marija@test.com',
    );
    expect(user.friendIds, isEmpty);
    expect(RelationshipStatus.values, contains(RelationshipStatus.none));
  });
}
