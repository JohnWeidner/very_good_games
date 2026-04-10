import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/games/chromix/cubit/chromix_cubit.dart';
import 'package:very_good_games/games/chromix/models/models.dart' as models;
import 'package:very_good_games/games/chromix/view/widgets/chromix_cell_widget.dart';
import 'package:very_good_games/games/chromix/view/widgets/chromix_grid.dart';

class _MockChromixCubit extends MockCubit<ChromixState>
    implements ChromixCubit {}

void main() {
  group('ChromixGrid', () {
    late ChromixCubit cubit;

    setUp(() {
      cubit = _MockChromixCubit();
      when(() => cubit.state).thenReturn(
        ChromixState(
          grid: models.ChromixGrid(
            cells: List.generate(16, (_) => const models.EmptyCell()),
          ),
          target: const {},
          optimalMoves: 5,
        ),
      );
    });

    Widget buildSubject() {
      return MaterialApp(
        home: Scaffold(
          body: BlocProvider<ChromixCubit>.value(
            value: cubit,
            child: const ChromixGrid(),
          ),
        ),
      );
    }

    testWidgets('renders 16 cells', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(ChromixCellWidget), findsNWidgets(16));
    });

    testWidgets('pan gesture calls startDrag', (tester) async {
      when(() => cubit.state).thenReturn(
        ChromixState(
          grid: models.ChromixGrid(
            cells: [
              const models.ColorCell(models.ChromixColor.red),
              ...List.generate(15, (_) => const models.EmptyCell()),
            ],
          ),
          target: const {},
          optimalMoves: 5,
        ),
      );

      await tester.pumpWidget(buildSubject());

      final gridFinder = find.byType(ChromixGrid);
      final topLeft = tester.getTopLeft(gridFinder);
      final startOffset = topLeft + const Offset(10, 10);

      await tester.dragFrom(startOffset, const Offset(50, 0));
      await tester.pumpAndSettle();

      verify(() => cubit.startDrag(any(), any())).called(1);
    });

    testWidgets('pan end calls endDrag', (tester) async {
      await tester.pumpWidget(buildSubject());

      final gridFinder = find.byType(ChromixGrid);
      final topLeft = tester.getTopLeft(gridFinder);
      final startOffset = topLeft + const Offset(10, 10);

      await tester.dragFrom(startOffset, const Offset(50, 0));
      await tester.pumpAndSettle();

      verify(() => cubit.endDrag()).called(1);
    });

    testWidgets('adjacent same-color cells share edges', (tester) async {
      // Two adjacent red cells should merge visually.
      when(() => cubit.state).thenReturn(
        ChromixState(
          grid: models.ChromixGrid(
            cells: [
              const models.ColorCell(models.ChromixColor.red),
              const models.ColorCell(models.ChromixColor.red),
              ...List.generate(14, (_) => const models.EmptyCell()),
            ],
          ),
          target: const {},
          optimalMoves: 5,
        ),
      );

      await tester.pumpWidget(buildSubject());

      // Find both red cells — they should have shared right/left edges.
      final cellWidgets = tester
          .widgetList<ChromixCellWidget>(find.byType(ChromixCellWidget))
          .toList();

      // Cell (0,0) should share right edge.
      expect(cellWidgets[0].edges.right, isTrue);
      // Cell (0,1) should share left edge.
      expect(cellWidgets[1].edges.left, isTrue);
    });
  });
}
