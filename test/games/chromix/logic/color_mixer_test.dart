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

    group('isComponentOf', () {
      test('red is a component of orange', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.red, ChromixColor.orange),
          isTrue,
        );
      });

      test('yellow is a component of orange', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.yellow, ChromixColor.orange),
          isTrue,
        );
      });

      test('red is a component of purple', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.red, ChromixColor.purple),
          isTrue,
        );
      });

      test('blue is a component of purple', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.blue, ChromixColor.purple),
          isTrue,
        );
      });

      test('yellow is a component of green', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.yellow, ChromixColor.green),
          isTrue,
        );
      });

      test('blue is a component of green', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.blue, ChromixColor.green),
          isTrue,
        );
      });

      test('blue is not a component of orange', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.blue, ChromixColor.orange),
          isFalse,
        );
      });

      test('yellow is not a component of purple', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.yellow, ChromixColor.purple),
          isFalse,
        );
      });

      test('red is not a component of green', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.red, ChromixColor.green),
          isFalse,
        );
      });

      test('secondary as primary input returns false', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.orange, ChromixColor.purple),
          isFalse,
        );
      });

      test('primary as secondary input returns false', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.red, ChromixColor.blue),
          isFalse,
        );
      });

      test('same secondary returns false', () {
        expect(
          ColorMixer.isComponentOf(ChromixColor.orange, ChromixColor.orange),
          isFalse,
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
