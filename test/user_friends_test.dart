import 'package:flutter_test/flutter_test.dart';
import 'package:timski/models/app_user.dart';
import 'package:timski/models/relationship_status.dart';

void main() {
  test('Тестирање на логиката за пријателства и статуси', () {
    // 1. Креираме тест корисник (Марија)
    final marija = AppUser(
      id: '1',
      name: 'Marija',
      username: 'marija_n',
      email: 'marija@test.com',
      friendsIds: [],
      sentRequestsIds: [],
      receivedRequestsIds: [],
    );

    final darkoId = '2';

    // Првично, статусот треба да биде 'none'
    expect(marija.getRelationshipWith(darkoId), RelationshipStatus.none);

    // 2. Марија му праќа барање на Дарко
    marija.sendFriendRequest(darkoId);
    expect(marija.getRelationshipWith(darkoId), RelationshipStatus.requestSent);

    // 3. Симулираме дека Дарко ѝ пратил барање на Марија
    marija.sentRequestsIds.remove(darkoId); // го ресетираме претходното барање
    marija.receivedRequestsIds.add(darkoId);
    expect(marija.getRelationshipWith(darkoId), RelationshipStatus.requestReceived);

    // 4. Марија го прифаќа барањето
    marija.acceptFriendRequest(darkoId);
    expect(marija.getRelationshipWith(darkoId), RelationshipStatus.friends);
    expect(marija.friendsIds.contains(darkoId), true);

    // 5. Марија го брише Дарко од пријатели
    marija.removeFriend(darkoId);
    expect(marija.getRelationshipWith(darkoId), RelationshipStatus.none);
  });
}