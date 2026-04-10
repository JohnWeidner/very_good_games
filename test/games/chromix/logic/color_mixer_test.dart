import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/logic/logic.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

void main() {
  group('ColorMixer', () {
    group('valid mixing pairs', () {
      test('red + yellow = orange', () {
        expect(
          ColorMixer.mix(ChromixColor.red, ChromixColor.yellow),
          equals(ChromixColor.orange),
        );
      });

      test('yellow + red = orange', () {
        expect(
          ColorMixer.mix(ChromixColor.yellow, ChromixColor.red),
          equals(ChromixColor.orange),
        );
      });

      test('red + blue = purple', () {
        expect(
          ColorMixer.mix(ChromixColor.red, ChromixColor.blue),
          equals(ChromixColor.purple),
        );
      });

      test('blue + red = purple', () {
        expect(
          ColorMixer.mix(ChromixColor.blue, ChromixColor.red),
          equals(ChromixColor.purple),
        );
      });

      test('yellow + blue = green', () {
        expect(
          ColorMixer.mix(ChromixColor.yellow, ChromixColor.blue),
          equals(ChromixColor.green),
        );
      });

      test('blue + yellow = green', () {
        expect(
          ColorMixer.mix(ChromixColor.blue, ChromixColor.yellow),
          equals(ChromixColor.green),
        );
      });
    });

    group('invalid combinations return null', () {
      test('same color returns null', () {
        expect(ColorMixer.mix(ChromixColor.red, ChromixColor.red), isNull);
        expect(ColorMixer.mix(ChromixColor.blue, ChromixColor.blue), isNull);
      });

      test('secondary as first input returns null', () {
        expect(ColorMixer.mix(ChromixColor.orange, ChromixColor.red), isNull);
        expect(ColorMixer.mix(ChromixColor.green, ChromixColor.blue), isNull);
        expect(
          ColorMixer.mix(ChromixColor.purple, ChromixColor.yellow),
          isNull,
        );
      });

      test('secondary as second input returns null', () {
        expect(ColorMixer.mix(ChromixColor.red, ChromixColor.orange), isNull);
      });

      test('two secondaries return null', () {
        expect(ColorMixer.mix(ChromixColor.orange, ChromixColor.green), isNull);
      });
    });
  });
}
