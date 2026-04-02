import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/guess_the_number/logic/logic.dart';

void main() {
  group('PrimeChecker', () {
    test('1 is not prime', () {
      expect(PrimeChecker.isPrime(1), isFalse);
    });

    test('2 is prime', () {
      expect(PrimeChecker.isPrime(2), isTrue);
    });

    test('known primes in range', () {
      for (final p in [3, 5, 7, 11, 13, 97, 389, 397]) {
        expect(PrimeChecker.isPrime(p), isTrue, reason: '$p should be prime');
      }
    });

    test('known composites in range', () {
      for (final c in [4, 6, 8, 9, 10, 100, 200, 400]) {
        expect(
          PrimeChecker.isPrime(c),
          isFalse,
          reason: '$c should not be prime',
        );
      }
    });
  });
}
