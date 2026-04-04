import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/games/signal/cubit/signal_cubit.dart';
import 'package:very_good_games/games/signal/logic/logic.dart';
import 'package:very_good_games/games/signal/view/widgets/signal_cell.dart';
import 'package:very_good_games/games/signal/view/widgets/signal_grid.dart';

class _MockSignalCubit extends MockCubit<SignalState> implements SignalCubit {}

void main() {
  group('SignalGrid', () {
    late SignalCubit cubit;

    SignalState _stateForSeed(int seed) {
      final result = PuzzleGenerator.generate(seed);
      final signals = SignalCalculator.calculate(result.puzzle);
      return SignalState(
        grid: result.puzzle,
        towerSignals: signals,
        solutionWallCount: result.solutionWallCount,
      );
    }

    setUp(() {
      cubit = _MockSignalCubit();
    });

    Widget buildSubject({int seed = 42}) {
      when(() => cubit.state).thenReturn(_stateForSeed(seed));

      return MaterialApp(
        home: Scaffold(
          body: BlocProvider<SignalCubit>.value(
            value: cubit,
            child: const SignalGrid(),
          ),
        ),
      );
    }

    testWidgets('renders correct number of cells for 5x5', (tester) async {
      // seed=42, 42 % 3 = 0 → 6x6. Use seed=1 for 5x5.
      await tester.pumpWidget(buildSubject(seed: 1));

      expect(find.byType(SignalCell), findsNWidgets(25));
    });

    testWidgets('renders correct number of cells for 6x6', (tester) async {
      await tester.pumpWidget(buildSubject(seed: 42));

      expect(find.byType(SignalCell), findsNWidgets(36));
    });

    testWidgets('calls toggleCell on tap', (tester) async {
      when(() => cubit.toggleCell(any(), any())).thenReturn(null);

      await tester.pumpWidget(buildSubject());

      // Tap the first cell.
      await tester.tap(find.byType(SignalCell).first);

      verify(() => cubit.toggleCell(any(), any())).called(1);
    });
  });
}
