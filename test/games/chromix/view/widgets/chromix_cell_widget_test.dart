import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/models/models.dart';
import 'package:very_good_games/games/chromix/view/widgets/chromix_cell_widget.dart';

void main() {
  group('ChromixCellWidget', () {
    Widget buildSubject(ChromixCell cell, {VoidCallback? onTap}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 50,
            height: 50,
            child: ChromixCellWidget(
              cell: cell,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders empty cell without label', (tester) async {
      await tester.pumpWidget(buildSubject(const EmptyCell()));

      expect(find.byType(Container), findsWidgets);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders blocker cell without label', (tester) async {
      await tester.pumpWidget(
        buildSubject(const BlockerCell()),
      );

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders color cell with letter label', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(const ColorCell(ChromixColor.red)),
      );

      expect(find.text('R'), findsOneWidget);
    });

    testWidgets('renders yellow cell with Y label', (tester) async {
      await tester.pumpWidget(
        buildSubject(const ColorCell(ChromixColor.yellow)),
      );

      expect(find.text('Y'), findsOneWidget);
    });

    testWidgets('renders secondary color labels', (tester) async {
      await tester.pumpWidget(
        buildSubject(const ColorCell(ChromixColor.orange)),
      );

      expect(find.text('O'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(
          const EmptyCell(),
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });
  });
}
