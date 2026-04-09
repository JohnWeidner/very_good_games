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

    testWidgets('renders without isCorrect set', (tester) async {
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

      expect(find.byType(BinWidget), findsOneWidget);
    });
  });
}
