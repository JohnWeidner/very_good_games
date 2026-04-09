import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/models/models.dart';
import 'package:very_good_games/games/cascade/view/widgets/ball_widget.dart';

void main() {
  group('BallWidget', () {
    testWidgets('displays ball label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BallWidget(ballId: BallId.ball1),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('displays correct label for each ball', (tester) async {
      for (final ball in BallId.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BallWidget(ballId: ball),
            ),
          ),
        );

        expect(find.text(ball.label), findsOneWidget);
      }
    });
  });

  group('ballColor', () {
    test('returns distinct color for each ball', () {
      final colors = BallId.values.map(ballColor).toSet();
      expect(colors.length, 3);
    });
  });
}
