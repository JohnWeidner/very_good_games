import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/models/models.dart';
import 'package:very_good_games/games/cascade/view/widgets/ball_tray.dart';
import 'package:very_good_games/games/cascade/view/widgets/ball_widget.dart';

void main() {
  group('BallTray', () {
    testWidgets('shows unassigned balls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BallTray(
              slotAssignments: const [BallId.ball1, null, null],
              onBallAssigned: (_, __) {},
              enabled: true,
            ),
          ),
        ),
      );

      // ball1 is assigned, ball2 and ball3 are unassigned.
      final ballWidgets = tester.widgetList<BallWidget>(
        find.byType(BallWidget),
      );
      expect(ballWidgets.length, 2);

      final ids = ballWidgets.map((w) => w.ballId).toSet();
      expect(ids, containsAll([BallId.ball2, BallId.ball3]));
    });

    testWidgets('shows no balls when all are assigned', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BallTray(
              slotAssignments: const [
                BallId.ball1,
                BallId.ball2,
                BallId.ball3,
              ],
              onBallAssigned: (_, __) {},
              enabled: true,
            ),
          ),
        ),
      );

      expect(find.byType(BallWidget), findsNothing);
    });

    testWidgets('balls are draggable when enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BallTray(
              slotAssignments: const [null, null, null],
              onBallAssigned: (_, __) {},
              enabled: true,
            ),
          ),
        ),
      );

      expect(find.byType(Draggable<BallId>), findsNWidgets(3));
    });

    testWidgets('balls are not draggable when disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BallTray(
              slotAssignments: const [null, null, null],
              onBallAssigned: (_, __) {},
              enabled: false,
            ),
          ),
        ),
      );

      expect(find.byType(Draggable<BallId>), findsNothing);
      expect(find.byType(BallWidget), findsNWidgets(3));
    });
  });
}
