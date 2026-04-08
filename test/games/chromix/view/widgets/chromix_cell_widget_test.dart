import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/models/models.dart';
import 'package:very_good_games/games/chromix/view/widgets/chromix_cell_widget.dart';

void main() {
  group('ChromixCellWidget', () {
    Widget buildSubject(
      ChromixCell cell, {
      CellEdges edges = CellEdges.none,
      bool isHighlighted = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 50,
            height: 50,
            child: ChromixCellWidget(
              cell: cell,
              edges: edges,
              isHighlighted: isHighlighted,
            ),
          ),
        ),
      );
    }

    testWidgets('renders empty cell', (tester) async {
      await tester.pumpWidget(buildSubject(const EmptyCell()));

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders blocker cell', (tester) async {
      await tester.pumpWidget(
        buildSubject(const BlockerCell()),
      );

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders color cell', (tester) async {
      await tester.pumpWidget(
        buildSubject(const ColorCell(ChromixColor.red)),
      );

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders highlight border when isHighlighted is true',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          const ColorCell(ChromixColor.red),
          isHighlighted: true,
        ),
      );

      final container = tester.widget<Container>(
        find.byType(Container).last,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('all corners rounded when no edges shared', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(const ColorCell(ChromixColor.red)),
      );

      final container = tester.widget<Container>(
        find.byType(Container).last,
      );
      final decoration = container.decoration! as BoxDecoration;
      final br = decoration.borderRadius! as BorderRadius;

      expect(br.topLeft, isNot(Radius.zero));
      expect(br.topRight, isNot(Radius.zero));
      expect(br.bottomLeft, isNot(Radius.zero));
      expect(br.bottomRight, isNot(Radius.zero));
    });

    testWidgets('corners flattened where edges are shared', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const ColorCell(ChromixColor.red),
          edges: const CellEdges(top: true, right: true),
        ),
      );

      final container = tester.widget<Container>(
        find.byType(Container).last,
      );
      final decoration = container.decoration! as BoxDecoration;
      final br = decoration.borderRadius! as BorderRadius;

      // top-left: top shared → flat
      expect(br.topLeft, Radius.zero);
      // top-right: both top and right shared → flat
      expect(br.topRight, Radius.zero);
      // bottom-left: neither shared → rounded
      expect(br.bottomLeft, isNot(Radius.zero));
      // bottom-right: right shared → flat
      expect(br.bottomRight, Radius.zero);
    });
  });
}
