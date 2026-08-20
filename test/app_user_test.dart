import 'package:flutter_test/flutter_test.dart';
import 'package:timski/models/app_user.dart';

void main() {
  group('AppUser', () {
    test('bio и friendIds стандардно се празни', () {
      final user = AppUser(id: 'u1', name: 'Марија', username: 'marija', email: 'm@test.mk');
      expect(user.bio, '');
      expect(user.friendIds, isEmpty);
    });

    test('copyWith менува само дадените полиња', () {
      final user = AppUser(
        id: 'u1',
        name: 'Марија',
        username: 'marija',
        email: 'm@test.mk',
        bio: 'Стара биографија',
      );

      final updated = user.copyWith(bio: 'Нова биографија');

      expect(updated.id, 'u1');
      expect(updated.name, 'Марија');
      expect(updated.username, 'marija');
      expect(updated.email, 'm@test.mk');
      expect(updated.bio, 'Нова биографија');
    });

    test('copyWith без аргументи ги задржува сите постоечки вредности', () {
      final user = AppUser(
        id: 'u1',
        name: 'Марија',
        username: 'marija',
        email: 'm@test.mk',
        bio: 'Биографија',
        friendIds: ['u2'],
      );

      final copy = user.copyWith();

      expect(copy.name, user.name);
      expect(copy.username, user.username);
      expect(copy.email, user.email);
      expect(copy.bio, user.bio);
      expect(copy.friendIds, user.friendIds);
    });

    test('copyWith го задржува истиот id — идентитетот на корисникот не се менува', () {
      final user = AppUser(id: 'u1', name: 'Марија', username: 'marija', email: 'm@test.mk');
      final copy = user.copyWith(name: 'Друго Име');
      expect(copy.id, 'u1');
    });
  });
}
