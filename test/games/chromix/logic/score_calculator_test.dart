import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/logic/logic.dart';

void main() {
  group('chromixScore', () {
    test('returns sum of moves and undos', () {
      expect(chromixScore(5, 3), equals(8));
    });

    test('returns 0 when no moves or undos', () {
      expect(chromixScore(0, 0), equals(0));
    });

    test('returns moves when no undos', () {
      expect(chromixScore(7, 0), equals(7));
    });

    test('returns undos when no moves', () {
      expect(chromixScore(0, 4), equals(4));
    });
  });

  group('chromixStars', () {
    test('returns 3 stars when score equals optimal', () {
      expect(chromixStars(5, 5), equals(3));
    });

    test('returns 3 stars when score is below optimal', () {
      expect(chromixStars(3, 5), equals(3));
    });

    test('returns 2 stars when score is optimal + 1', () {
      expect(chromixStars(6, 5), equals(2));
    });

    test('returns 2 stars when score is optimal + 3', () {
      expect(chromixStars(8, 5), equals(2));
    });

    test('returns 1 star when score exceeds optimal + 3', () {
      expect(chromixStars(9, 5), equals(1));
    });

    test('returns 1 star for very high score', () {
      expect(chromixStars(100, 5), equals(1));
    });
  });
}
