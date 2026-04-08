import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/view/widgets/instructions_dialog.dart';

void main() {
  group('ChromixInstructionsDialog', () {
    testWidgets('displays and dismisses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    ChromixInstructionsDialog.show(context),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('How to Play'), findsWidgets);
      expect(find.text('Color Mixing (RYB)'), findsOneWidget);
      expect(
        find.textContaining('Red + Yellow = Orange'),
        findsOneWidget,
      );
      expect(
        find.text('Drag to Spread Color'),
        findsOneWidget,
      );
      expect(
        find.text('Contiguity Rule'),
        findsOneWidget,
      );

      await tester.tap(find.text('Got it!'));
      await tester.pumpAndSettle();

      expect(
        find.text('Color Mixing (RYB)'),
        findsNothing,
      );
    });
  });
}
