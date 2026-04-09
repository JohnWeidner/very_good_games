import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/logic/logic.dart';

void main() {
  group('cascadeScore', () {
    test('returns 100 for first attempt', () {
      expect(cascadeScore(1), 100);
    });

    test('returns 75 for second attempt', () {
      expect(cascadeScore(2), 75);
    });

    test('returns 50 for third attempt', () {
      expect(cascadeScore(3), 50);
    });

    test('returns 25 for fourth attempt', () {
      expect(cascadeScore(4), 25);
    });

    test('returns minimum 10 for 5+ attempts', () {
      expect(cascadeScore(5), 10);
      expect(cascadeScore(10), 10);
      expect(cascadeScore(100), 10);
    });
  });

  group('cascadeStars', () {
    test('returns 3 stars for first attempt', () {
      expect(cascadeStars(1), 3);
    });

    test('returns 2 stars for 2 attempts', () {
      expect(cascadeStars(2), 2);
    });

    test('returns 2 stars for 3 attempts', () {
      expect(cascadeStars(3), 2);
    });

    test('returns 1 star for 4+ attempts', () {
      expect(cascadeStars(4), 1);
      expect(cascadeStars(10), 1);
    });
  });
}
