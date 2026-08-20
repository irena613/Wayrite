import 'package:flutter_test/flutter_test.dart';
import 'package:timski/models/post.dart';

Post _post({
  required PostType type,
  required DateTime startDate,
  DateTime? endDate,
  Set<String>? likedBy,
  List<String>? commentIds,
}) {
  return Post(
    id: 'p1',
    authorId: 'u1',
    type: type,
    title: 'Тест',
    description: 'Опис',
    startDate: startDate,
    endDate: endDate,
    createdAt: DateTime.now(),
    likedBy: likedBy,
    commentIds: commentIds,
  );
}

void main() {
  group('Post.durationDays', () {
    test('го брои бројот на денови помеѓу startDate и endDate', () {
      final post = _post(
        type: PostType.quit,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 11),
      );
      expect(post.durationDays, 10);
    });

    test('без endDate се пресметува до денес', () {
      final start = DateTime.now().subtract(const Duration(days: 5));
      final post = _post(type: PostType.quit, startDate: start);
      expect(post.durationDays, 5);
    });

    test('никогаш не е негативен (endDate пред startDate)', () {
      final post = _post(
        type: PostType.quit,
        startDate: DateTime(2026, 1, 11),
        endDate: DateTime(2026, 1, 1),
      );
      expect(post.durationDays, 0);
    });
  });

  group('Post.streakDays', () {
    test('за Quit објава е еднаков на durationDays', () {
      final post = _post(
        type: PostType.quit,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );
      expect(post.streakDays, post.durationDays);
      expect(post.streakDays, 30);
    });

    test('за Achievement објава е секогаш 0, дури и со долго времетраење', () {
      final post = _post(
        type: PostType.achievement,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 1),
      );
      expect(post.streakDays, 0);
    });
  });

  group('Post.likeCount / commentCount / likedByUser', () {
    test('likeCount и likedByUser го одразуваат likedBy сетот', () {
      final post = _post(
        type: PostType.achievement,
        startDate: DateTime(2026, 1, 1),
        likedBy: {'u2', 'u3'},
      );
      expect(post.likeCount, 2);
      expect(post.likedByUser('u2'), isTrue);
      expect(post.likedByUser('u9'), isFalse);
    });

    test('commentCount ја одразува должината на commentIds', () {
      final post = _post(
        type: PostType.achievement,
        startDate: DateTime(2026, 1, 1),
        commentIds: ['c1', 'c2', 'c3'],
      );
      expect(post.commentCount, 3);
    });

    test('стандардно likedBy и commentIds се празни', () {
      final post = _post(type: PostType.achievement, startDate: DateTime(2026, 1, 1));
      expect(post.likeCount, 0);
      expect(post.commentCount, 0);
    });
  });

  group('Post.toFirestore', () {
    test('го сериjaлизира типот како име на enum-от', () {
      final post = _post(type: PostType.quit, startDate: DateTime(2026, 1, 1));
      expect(post.toFirestore()['type'], 'quit');
    });

    test('не вклучува endDate поле кога е null', () {
      final post = _post(type: PostType.achievement, startDate: DateTime(2026, 1, 1));
      expect(post.toFirestore().containsKey('endDate'), isFalse);
    });

    test('вклучува endDate поле кога е зададен', () {
      final post = _post(
        type: PostType.achievement,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 5),
      );
      expect(post.toFirestore().containsKey('endDate'), isTrue);
    });
  });

  group('PostTypeX.label', () {
    test('дава чит-лив назив на македонски за секој тип', () {
      expect(PostType.achievement.label, 'Постигнување');
      expect(PostType.quit.label, 'Откажување');
    });
  });
}
