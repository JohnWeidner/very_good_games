import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/models/models.dart';
import 'package:very_good_games/games/cascade/view/widgets/lever_widget.dart';

void main() {
  group('LeverWidget', () {
    testWidgets('calls onTap when enabled and tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeverWidget(
              lever: const Lever(
                row: 0,
                col: 0,
                direction: LeverDirection.left,
              ),
              cellSize: 60,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(LeverWidget));
      expect(tapped, isTrue);
    });

    testWidgets('does not call onTap when disabled', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeverWidget(
              lever: const Lever(
                row: 0,
                col: 0,
                direction: LeverDirection.right,
              ),
              cellSize: 60,
              enabled: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(LeverWidget));
      expect(tapped, isFalse);
    });
  });
}
