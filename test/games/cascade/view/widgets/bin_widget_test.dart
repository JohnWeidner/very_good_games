import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/models/models.dart';
import 'package:very_good_games/games/cascade/view/widgets/bin_widget.dart';

void main() {
  group('BinWidget', () {
    testWidgets('displays expected ball label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BinWidget(
              expectedBallId: BallId.ball2,
              cellSize: 60,
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('displays each ball label correctly', (tester) async {
      for (final ball in BallId.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BinWidget(
                expectedBallId: ball,
                cellSize: 60,
              ),
            ),
          ),
        );

        expect(find.text(ball.label), findsOneWidget);
      }
    });

    testWidgets('has three-sided border (no top)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BinWidget(
              expectedBallId: BallId.ball1,
              cellSize: 60,
            ),
          ),
        ),
      );

      // Find the Container with the border decoration.
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BinWidget),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top, BorderSide.none);
      expect(border.left.color, isNot(Colors.transparent));
      expect(border.right.color, isNot(Colors.transparent));
      expect(border.bottom.color, isNot(Colors.transparent));
    });
  });
}
