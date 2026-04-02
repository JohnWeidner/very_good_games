import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/guess_the_number/logic/logic.dart';

void main() {
  group('ScoreCalculator', () {
    test('starting budget is 600', () {
      expect(ScoreCalculator.startingBudget, equals(600));
    });

    test('perfect game (1 question, 0 seconds) returns 550', () {
      expect(
        ScoreCalculator.calculate(questions: 1, seconds: 0),
        equals(550),
      );
    });

    test('typical game returns expected score', () {
      // 9 questions, 60 seconds = 600 - 450 - 120 = 30
      expect(
        ScoreCalculator.calculate(questions: 9, seconds: 60),
        equals(30),
      );
    });

    test('score clamps to 0 for very long games', () {
      expect(
        ScoreCalculator.calculate(questions: 50, seconds: 600),
        equals(0),
      );
    });

    test('0 questions and 0 seconds returns 600', () {
      expect(
        ScoreCalculator.calculate(questions: 0, seconds: 0),
        equals(600),
      );
    });

    test('time penalty of 2 per second applies correctly', () {
      final withTime = ScoreCalculator.calculate(
        questions: 1,
        seconds: 10,
      );
      final withoutTime = ScoreCalculator.calculate(
        questions: 1,
        seconds: 0,
      );
      expect(withoutTime - withTime, equals(20));
    });

    test('max time at 0 questions is 300 seconds (5 min)', () {
      expect(
        ScoreCalculator.calculate(questions: 0, seconds: 300),
        equals(0),
      );
      expect(
        ScoreCalculator.calculate(questions: 0, seconds: 299),
        greaterThan(0),
      );
    });

    test('max questions at 0 seconds is 12', () {
      expect(
        ScoreCalculator.calculate(questions: 12, seconds: 0),
        equals(0),
      );
      expect(
        ScoreCalculator.calculate(questions: 11, seconds: 0),
        greaterThan(0),
      );
    });
  });
}
