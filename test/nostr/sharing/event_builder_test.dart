import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/nostr/sharing/event_builder.dart';

void main() {
  group('EventBuilder', () {
    group('buildGuessTheNumberResult', () {
      late Map<String, dynamic> result;

      setUp(() {
        final event = EventBuilder.buildGuessTheNumberResult(
          pubKeyHex: 'abc123',
          score: 350,
          stars: 2,
          questionCount: 8,
          elapsedSeconds: 102,
          date: '2026-04-02',
        );
        result = {
          'kind': event.kind,
          'pubKey': event.pubKey,
          'tags': event.tags,
          'content': event.content,
        };
      });

      test('uses kind 30042', () {
        expect(result['kind'], equals(30042));
      });

      test('sets correct pubKey', () {
        expect(result['pubKey'], equals('abc123'));
      });

      test('includes d tag with game and date', () {
        final tags = result['tags'] as List<List<String>>;
        final dTag = tags.firstWhere((t) => t[0] == 'd');
        expect(dTag[1], equals('guess-the-number:2026-04-02'));
      });

      test('includes t tags for vgg and game', () {
        final tags = result['tags'] as List<List<String>>;
        final tTags = tags.where((t) => t[0] == 't').toList();
        expect(tTags.length, equals(2));
        expect(tTags[0][1], equals('vgg'));
        expect(tTags[1][1], equals('guess-the-number'));
      });

      test('includes NIP-32 label namespace', () {
        final tags = result['tags'] as List<List<String>>;
        final lTag = tags.firstWhere((t) => t[0] == 'L');
        expect(lTag[1], equals('games.vgg.score'));
      });

      test('includes NIP-32 labels for score, stars, questions, time', () {
        final tags = result['tags'] as List<List<String>>;
        final labels = tags.where((t) => t[0] == 'l').toList();
        expect(labels.length, equals(4));
        expect(labels[0][1], equals('score-350'));
        expect(labels[1][1], equals('stars-2'));
        expect(labels[2][1], equals('questions-8'));
        expect(labels[3][1], equals('time-102'));

        // All under the correct namespace.
        for (final label in labels) {
          expect(label[2], equals('games.vgg.score'));
        }
      });

      test('content includes score, stars, questions, and formatted time', () {
        final content = result['content'] as String;
        expect(content, contains('Guess the Number'));
        expect(content, contains('350 points'));
        expect(content, contains('2 Stars'));
        expect(content, contains('8 questions'));
        expect(content, contains('01:42'));
        expect(content, contains('2026-04-02'));
      });

      test('content includes star emoji', () {
        final content = result['content'] as String;
        expect(content, contains('\u2b50\u2b50'));
      });
    });

    group('buildChromixResult', () {
      late Map<String, dynamic> result;

      setUp(() {
        final event = EventBuilder.buildChromixResult(
          pubKeyHex: 'abc123',
          score: 12,
          stars: 2,
          moves: 10,
          undos: 2,
          elapsedSeconds: 95,
          date: '2026-04-07',
        );
        result = {
          'kind': event.kind,
          'pubKey': event.pubKey,
          'tags': event.tags,
          'content': event.content,
        };
      });

      test('uses kind 30042', () {
        expect(result['kind'], equals(30042));
      });

      test('includes d tag with chromix and date', () {
        final tags = result['tags'] as List<List<String>>;
        final dTag = tags.firstWhere((t) => t[0] == 'd');
        expect(dTag[1], equals('chromix:2026-04-07'));
      });

      test('includes t tags for vgg and chromix', () {
        final tags = result['tags'] as List<List<String>>;
        final tTags = tags.where((t) => t[0] == 't').toList();
        expect(tTags.length, equals(2));
        expect(tTags[0][1], equals('vgg'));
        expect(tTags[1][1], equals('chromix'));
      });

      test('includes NIP-32 labels for score, stars, moves, undos, time', () {
        final tags = result['tags'] as List<List<String>>;
        final labels = tags.where((t) => t[0] == 'l').toList();
        expect(labels.length, equals(5));
        expect(labels[0][1], equals('score-12'));
        expect(labels[1][1], equals('stars-2'));
        expect(labels[2][1], equals('moves-10'));
        expect(labels[3][1], equals('undos-2'));
        expect(labels[4][1], equals('time-95'));
      });

      test('content includes Chromix game info', () {
        final content = result['content'] as String;
        expect(content, contains('Chromix'));
        expect(content, contains('2 Stars'));
        expect(content, contains('12 total'));
        expect(content, contains('10 moves'));
        expect(content, contains('2 undos'));
        expect(content, contains('01:35'));
        expect(content, contains('2026-04-07'));
      });

      test('content includes star emoji', () {
        final content = result['content'] as String;
        expect(content, contains('\u2b50\u2b50'));
      });
    });

    group('buildSignalResult', () {
      late Map<String, dynamic> result;

      setUp(() {
        final event = EventBuilder.buildSignalResult(
          pubKeyHex: 'abc123',
          score: 400,
          stars: 3,
          moveCount: 5,
          elapsedSeconds: 45,
          date: '2026-04-03',
        );
        result = {
          'kind': event.kind,
          'pubKey': event.pubKey,
          'tags': event.tags,
          'content': event.content,
        };
      });

      test('uses kind 30042', () {
        expect(result['kind'], equals(30042));
      });

      test('includes d tag with signal and date', () {
        final tags = result['tags'] as List<List<String>>;
        final dTag = tags.firstWhere((t) => t[0] == 'd');
        expect(dTag[1], equals('signal:2026-04-03'));
      });

      test('includes t tags for vgg and signal', () {
        final tags = result['tags'] as List<List<String>>;
        final tTags = tags.where((t) => t[0] == 't').toList();
        expect(tTags.length, equals(2));
        expect(tTags[0][1], equals('vgg'));
        expect(tTags[1][1], equals('signal'));
      });

      test('includes NIP-32 labels for score, stars, moves, time', () {
        final tags = result['tags'] as List<List<String>>;
        final labels = tags.where((t) => t[0] == 'l').toList();
        expect(labels.length, equals(4));
        expect(labels[0][1], equals('score-400'));
        expect(labels[1][1], equals('stars-3'));
        expect(labels[2][1], equals('moves-5'));
        expect(labels[3][1], equals('time-45'));
      });

      test('content includes Signal game info', () {
        final content = result['content'] as String;
        expect(content, contains('Signal'));
        expect(content, contains('400 points'));
        expect(content, contains('3 Stars'));
        expect(content, contains('5 moves'));
        expect(content, contains('00:45'));
        expect(content, contains('2026-04-03'));
      });
    });

    group('buildCascadeResult', () {
      late Map<String, dynamic> result;

      setUp(() {
        final event = EventBuilder.buildCascadeResult(
          pubKeyHex: 'abc123',
          score: 100,
          stars: 3,
          attempts: 1,
          elapsedSeconds: 120,
          date: '2026-04-08',
        );
        result = {
          'kind': event.kind,
          'pubKey': event.pubKey,
          'tags': event.tags,
          'content': event.content,
        };
      });

      test('uses kind 30042', () {
        expect(result['kind'], equals(30042));
      });

      test('includes d tag with cascade and date', () {
        final tags = result['tags'] as List<List<String>>;
        final dTag = tags.firstWhere((t) => t[0] == 'd');
        expect(dTag[1], equals('cascade:2026-04-08'));
      });

      test('includes t tags for vgg and cascade', () {
        final tags = result['tags'] as List<List<String>>;
        final tTags = tags.where((t) => t[0] == 't').toList();
        expect(tTags.length, equals(2));
        expect(tTags[0][1], equals('vgg'));
        expect(tTags[1][1], equals('cascade'));
      });

      test('includes NIP-32 labels for score, stars, attempts, time', () {
        final tags = result['tags'] as List<List<String>>;
        final labels = tags.where((t) => t[0] == 'l').toList();
        expect(labels.length, equals(4));
        expect(labels[0][1], equals('score-100'));
        expect(labels[1][1], equals('stars-3'));
        expect(labels[2][1], equals('attempts-1'));
        expect(labels[3][1], equals('time-120'));
      });

      test('content includes Cascade game info', () {
        final content = result['content'] as String;
        expect(content, contains('Cascade'));
        expect(content, contains('3 Stars'));
        expect(content, contains('100 points'));
        expect(content, contains('1 attempt'));
        expect(content, contains('02:00'));
        expect(content, contains('2026-04-08'));
      });
    });
  });
}
