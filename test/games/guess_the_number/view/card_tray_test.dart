import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';
import 'package:very_good_games/games/guess_the_number/view/widgets/card_tray.dart';

void main() {
  group('CardTray', () {
    testWidgets('renders all question type labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardTray(
              usedTypes: const {},
              onSelect: (_) {},
            ),
          ),
        ),
      );
      for (final type in QuestionType.values) {
        expect(
          find.text(type.label),
          findsWidgets,
          reason: '${type.name} label should be visible',
        );
      }
    });

    testWidgets('calls onSelect when unused card is tapped',
        (tester) async {
      QuestionType? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardTray(
              usedTypes: const {},
              onSelect: (t) => selected = t,
            ),
          ),
        ),
      );
      // Tap the first card (lessThan).
      await tester.tap(find.text(QuestionType.lessThan.label).first);
      expect(selected, equals(QuestionType.lessThan));
    });

    testWidgets('does not call onSelect for used card', (tester) async {
      QuestionType? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardTray(
              usedTypes: const {QuestionType.isOdd},
              onSelect: (t) => selected = t,
            ),
          ),
        ),
      );
      await tester.tap(find.text(QuestionType.isOdd.label).first);
      expect(selected, isNull);
    });

    testWidgets('renders descriptions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardTray(
              usedTypes: const {},
              onSelect: (_) {},
            ),
          ),
        ),
      );
      expect(
        find.text(QuestionType.lessThan.description),
        findsWidgets,
      );
    });
  });
}
