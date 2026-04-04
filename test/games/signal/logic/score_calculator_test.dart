import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/signal/logic/logic.dart';

void main() {
  group('SignalScoreCalculator', () {
    group('calculate', () {
      test('returns 500 for 0 moves', () {
        expect(SignalScoreCalculator.calculate(0), equals(500));
      });

      test('deducts 20 per move', () {
        expect(SignalScoreCalculator.calculate(5), equals(400));
        expect(SignalScoreCalculator.calculate(10), equals(300));
      });

      test('returns 0 when moves exceed budget', () {
        expect(SignalScoreCalculator.calculate(25), equals(0));
        expect(SignalScoreCalculator.calculate(100), equals(0));
      });

      test('returns exactly 0 at boundary', () {
        expect(SignalScoreCalculator.calculate(25), equals(0));
      });
    });

    group('stars', () {
      test('returns 3 stars for score >= 400', () {
        expect(SignalScoreCalculator.stars(500), equals(3));
        expect(SignalScoreCalculator.stars(400), equals(3));
      });

      test('returns 2 stars for score >= 250', () {
        expect(SignalScoreCalculator.stars(399), equals(2));
        expect(SignalScoreCalculator.stars(250), equals(2));
      });

      test('returns 1 star for score < 250', () {
        expect(SignalScoreCalculator.stars(249), equals(1));
        expect(SignalScoreCalculator.stars(1), equals(1));
        expect(SignalScoreCalculator.stars(0), equals(1));
      });
    });
  });
}
