/// Efficient prime check for numbers 1–400 using a precomputed set.
class PrimeChecker {
  PrimeChecker._();

  /// The set of all prime numbers from 1 to 400.
  /// There are 78 primes in this range.
  static final _primes = _computePrimes();

  /// Returns `true` if [n] is prime.
  ///
  /// Uses O(1) lookup against a precomputed set.
  static bool isPrime(int n) => _primes.contains(n);

  static Set<int> _computePrimes() {
    final sieve = List.filled(401, true);
    sieve[0] = false;
    sieve[1] = false;
    for (var i = 2; i * i <= 400; i++) {
      if (sieve[i]) {
        for (var j = i * i; j <= 400; j += i) {
          sieve[j] = false;
        }
      }
    }
    return {
      for (var i = 2; i <= 400; i++)
        if (sieve[i]) i,
    };
  }
}
