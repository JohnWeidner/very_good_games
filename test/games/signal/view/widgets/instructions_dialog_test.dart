import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/signal/view/widgets/instructions_dialog.dart';

void main() {
  group('SignalInstructionsDialog', () {
    testWidgets('renders How to Play title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SignalInstructionsDialog()),
      );

      // Title + section heading both say "How to Play".
      expect(find.text('How to Play'), findsNWidgets(2));
    });

    testWidgets('renders all sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SignalInstructionsDialog()),
      );

      expect(find.text('Goal'), findsOneWidget);
      expect(find.text('Towers & Signals'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Got it!'), findsOneWidget);
    });

    testWidgets('Got it button dismisses dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SignalInstructionsDialog.show(context),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Goal'), findsOneWidget);

      await tester.tap(find.text('Got it!'));
      await tester.pumpAndSettle();

      expect(find.text('Goal'), findsNothing);
    });
  });
}
