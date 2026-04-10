import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/games/cascade/cubit/cascade_cubit.dart';
import 'package:very_good_games/games/cascade/logic/logic.dart';
import 'package:very_good_games/games/cascade/models/models.dart';
import 'package:very_good_games/games/cascade/view/widgets/widgets.dart';

class _MockCascadeCubit extends MockCubit<CascadeState>
    implements CascadeCubit {}

void main() {
  group('CascadeBoardWidget', () {
    late CascadeCubit cubit;

    const levers = [
      Lever(row: 2, col: 1, direction: LeverDirection.left),
      Lever(row: 4, col: 3, direction: LeverDirection.right),
    ];

    final board = CascadeBoard(levers: levers, binOrder: const [0, 1, 2]);

    setUp(() {
      cubit = _MockCascadeCubit();
      when(
        () => cubit.state,
      ).thenReturn(CascadeState(board: board, initialLevers: levers));
    });

    Widget buildSubject() {
      return MaterialApp(
        home: Scaffold(
          body: BlocProvider<CascadeCubit>.value(
            value: cubit,
            child: const CascadeBoardWidget(),
          ),
        ),
      );
    }

    testWidgets('renders lever widgets in configuring state', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(LeverWidget), findsNWidgets(2));
    });

    testWidgets('renders bin widgets', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(BinWidget), findsNWidgets(3));
    });

    testWidgets('levers are enabled in configuring state', (tester) async {
      await tester.pumpWidget(buildSubject());

      final leverWidgets = tester
          .widgetList<LeverWidget>(find.byType(LeverWidget))
          .toList();

      for (final lever in leverWidgets) {
        expect(lever.enabled, isTrue);
      }
    });

    testWidgets('levers are disabled in won state', (tester) async {
      when(() => cubit.state).thenReturn(
        CascadeState(
          board: board,
          initialLevers: levers,
          status: CascadeStatus.won,
          score: 100,
        ),
      );

      await tester.pumpWidget(buildSubject());

      final leverWidgets = tester
          .widgetList<LeverWidget>(find.byType(LeverWidget))
          .toList();

      for (final lever in leverWidgets) {
        expect(lever.enabled, isFalse);
      }
    });

    testWidgets('levers are disabled in failed state', (tester) async {
      when(() => cubit.state).thenReturn(
        CascadeState(
          board: board,
          initialLevers: levers,
          status: CascadeStatus.failed,
          attempts: 1,
        ),
      );

      await tester.pumpWidget(buildSubject());

      final leverWidgets = tester
          .widgetList<LeverWidget>(find.byType(LeverWidget))
          .toList();

      for (final lever in leverWidgets) {
        expect(lever.enabled, isFalse);
      }
    });

    testWidgets('renders drop slots with assigned balls', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Default slot assignments: ball1, ball2, ball3.
      expect(find.byType(BallWidget), findsNWidgets(3));
    });

    testWidgets('renders landed balls in won state', (tester) async {
      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      when(() => cubit.state).thenReturn(
        CascadeState(
          board: board,
          initialLevers: levers,
          status: CascadeStatus.won,
          attempts: 1,
          dropResult: result,
          score: 100,
        ),
      );

      await tester.pumpWidget(buildSubject());

      // 3 landed balls should be rendered.
      expect(find.byType(BallWidget), findsNWidgets(3));
    });

    testWidgets('tap calls skipAnimation when dropping', (tester) async {
      final result = BallSimulator.simulate(
        board: board,
        slotAssignments: [BallId.ball1, BallId.ball2, BallId.ball3],
      );

      when(() => cubit.state).thenReturn(
        CascadeState(
          board: board,
          initialLevers: levers,
          status: CascadeStatus.dropping,
          attempts: 1,
          dropResult: result,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(GestureDetector).first);

      verify(() => cubit.skipAnimation()).called(1);
    });
  });
}
