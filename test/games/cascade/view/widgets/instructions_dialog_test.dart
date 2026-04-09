import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/cascade/view/widgets/instructions_dialog.dart';

void main() {
  group('CascadeInstructionsDialog', () {
    testWidgets('displays and dismisses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    CascadeInstructionsDialog.show(context),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('How to Play'), findsWidgets);
      expect(find.text('Goal'), findsOneWidget);
      expect(find.text('Setup'), findsOneWidget);
      expect(find.text('Levers'), findsOneWidget);
      expect(find.text('Drop'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);

      await tester.tap(find.text('Got it!'));
      await tester.pumpAndSettle();

      expect(find.text('Levers'), findsNothing);
    });
  });
}
