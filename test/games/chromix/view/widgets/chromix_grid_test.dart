import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/games/chromix/cubit/chromix_cubit.dart';
import 'package:very_good_games/games/chromix/models/models.dart'
    as models;
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
            cells: List.generate(
              16,
              (_) => const models.EmptyCell(),
            ),
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

    testWidgets('tapping a cell calls placeColor', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byType(ChromixCellWidget).first);

      verify(() => cubit.placeColor(0, 0)).called(1);
    });
  });
}
