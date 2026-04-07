import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/games/chromix/cubit/chromix_cubit.dart';
import 'package:very_good_games/games/chromix/models/models.dart';
import 'package:very_good_games/games/chromix/view/widgets/color_palette.dart';

class _MockChromixCubit extends MockCubit<ChromixState>
    implements ChromixCubit {}

void main() {
  group('ColorPalette', () {
    late ChromixCubit cubit;

    setUp(() {
      cubit = _MockChromixCubit();
      when(() => cubit.state).thenReturn(
        ChromixState(
          grid: ChromixGrid(
            cells: List.generate(16, (_) => const EmptyCell()),
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
            child: const ColorPalette(),
          ),
        ),
      );
    }

    testWidgets('renders 3 color buttons', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('R'), findsOneWidget);
      expect(find.text('Y'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('tapping yellow calls selectColor', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Y'));

      verify(
        () => cubit.selectColor(ChromixColor.yellow),
      ).called(1);
    });
  });
}
