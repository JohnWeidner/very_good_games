import 'package:ndk/ndk.dart';

/// Builds kind 30042 Nostr events for game results.
///
/// Each game has its own builder method with game-specific tags and content.
class EventBuilder {
  /// Builds an unsigned kind 30042 event for a Guess the Number result.
  ///
  /// The [pubKeyHex] is the hex-encoded public key of the signer.
  /// The [date] should be a UTC date string (e.g. "2026-04-02").
  static Nip01Event buildGuessTheNumberResult({
    required String pubKeyHex,
    required int score,
    required int stars,
    required int questionCount,
    required int elapsedSeconds,
    required String date,
  }) {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    final timeText =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';

    final starEmoji = '\u2b50' * stars;

    final content =
        '\ud83c\udfaf Very Good Games \u2014 Guess the Number\n'
        '\ud83c\udfaf $score points \u00b7 $starEmoji $stars Stars\n'
        '\ud83d\udcac $questionCount questions \u00b7 '
        '\u23f1 $timeText\n\n$date';

    return Nip01Event(
      pubKey: pubKeyHex,
      kind: 30042,
      tags: [
        ['d', 'guess-the-number:$date'],
        ['t', 'vgg'],
        ['t', 'guess-the-number'],
        ['L', 'games.vgg.score'],
        ['l', 'score-$score', 'games.vgg.score'],
        ['l', 'stars-$stars', 'games.vgg.score'],
        ['l', 'questions-$questionCount', 'games.vgg.score'],
        ['l', 'time-$elapsedSeconds', 'games.vgg.score'],
      ],
      content: content,
    );
  }

  /// Builds an unsigned kind 30042 event for a Chromix puzzle result.
  static Nip01Event buildChromixResult({
    required String pubKeyHex,
    required int score,
    required int stars,
    required int moves,
    required int undos,
    required String date,
  }) {
    final starEmoji = '\u2b50' * stars;

    final content =
        '\ud83c\udfa8 Very Good Games \u2014 Chromix\n'
        '\ud83c\udfaf $stars Stars \u00b7 $starEmoji\n'
        '\ud83e\udde9 $score total '
        '($moves moves, $undos undos)\n\n$date';

    return Nip01Event(
      pubKey: pubKeyHex,
      kind: 30042,
      tags: [
        ['d', 'chromix:$date'],
        ['t', 'vgg'],
        ['t', 'chromix'],
        ['L', 'games.vgg.score'],
        ['l', 'score-$score', 'games.vgg.score'],
        ['l', 'stars-$stars', 'games.vgg.score'],
        ['l', 'moves-$moves', 'games.vgg.score'],
        ['l', 'undos-$undos', 'games.vgg.score'],
      ],
      content: content,
    );
  }

  /// Builds an unsigned kind 30042 event for a Cascade puzzle result.
  static Nip01Event buildCascadeResult({
    required String pubKeyHex,
    required int score,
    required int stars,
    required int attempts,
    required String date,
  }) {
    final starEmoji = '\u2b50' * stars;

    final content =
        '\ud83c\udfb1 Very Good Games \u2014 Cascade\n'
        '\ud83c\udfaf $stars Stars \u00b7 $starEmoji\n'
        '\ud83e\udde9 $score points '
        '($attempts ${attempts == 1 ? 'attempt' : 'attempts'})\n\n$date';

    return Nip01Event(
      pubKey: pubKeyHex,
      kind: 30042,
      tags: [
        ['d', 'cascade:$date'],
        ['t', 'vgg'],
        ['t', 'cascade'],
        ['L', 'games.vgg.score'],
        ['l', 'score-$score', 'games.vgg.score'],
        ['l', 'stars-$stars', 'games.vgg.score'],
        ['l', 'attempts-$attempts', 'games.vgg.score'],
      ],
      content: content,
    );
  }

  /// Builds an unsigned kind 30042 event for a Signal puzzle result.
  static Nip01Event buildSignalResult({
    required String pubKeyHex,
    required int score,
    required int stars,
    required int moveCount,
    required String date,
  }) {
    final starEmoji = '\u2b50' * stars;

    final content =
        '\ud83d\udce1 Very Good Games \u2014 Signal\n'
        '\ud83c\udfaf $score points \u00b7 $starEmoji $stars Stars\n'
        '\ud83e\uddf1 $moveCount moves\n\n$date';

    return Nip01Event(
      pubKey: pubKeyHex,
      kind: 30042,
      tags: [
        ['d', 'signal:$date'],
        ['t', 'vgg'],
        ['t', 'signal'],
        ['L', 'games.vgg.score'],
        ['l', 'score-$score', 'games.vgg.score'],
        ['l', 'stars-$stars', 'games.vgg.score'],
        ['l', 'moves-$moveCount', 'games.vgg.score'],
      ],
      content: content,
    );
  }
}
