import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/signal/models/models.dart';
import 'package:very_good_games/games/signal/view/widgets/signal_cell.dart';

void main() {
  group('SignalCell', () {
    Widget buildSubject(
      Cell cell, {
      int? signalCount,
      bool isSignaled = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 50,
            height: 50,
            child: SignalCell(
              cell: cell,
              signalCount: signalCount,
              isSignaled: isSignaled,
            ),
          ),
        ),
      );
    }

    testWidgets('renders empty cell', (tester) async {
      await tester.pumpWidget(buildSubject(Cell.empty));
      // Empty cell renders a DecoratedBox — no text.
      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets('renders wall cell', (tester) async {
      await tester.pumpWidget(buildSubject(Cell.wall));
      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets('renders tower cell with target count', (tester) async {
      await tester.pumpWidget(buildSubject(Cell.tower(5), signalCount: 3));

      // Shows target number only, not current signal count.
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('tower cell shows check icon when satisfied', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(Cell.tower(4), signalCount: 4));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tower cell shows warning icon when over target', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(Cell.tower(2), signalCount: 5));

      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('tower cell shows no icon when under target', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(Cell.tower(5), signalCount: 1));

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.warning), findsNothing);
    });

    testWidgets('tower cell has semantic label', (tester) async {
      await tester.pumpWidget(buildSubject(Cell.tower(4), signalCount: 4));

      expect(
        find.bySemanticsLabel(RegExp('Tower.*target 4.*current 4.*satisfied')),
        findsOneWidget,
      );
    });

    testWidgets('tower cell shows over status when count > target', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(Cell.tower(2), signalCount: 5));

      expect(find.bySemanticsLabel(RegExp('over')), findsOneWidget);
    });

    testWidgets('tower cell shows under status when count < target', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(Cell.tower(5), signalCount: 1));

      expect(find.bySemanticsLabel(RegExp('under')), findsOneWidget);
    });
  });
}
