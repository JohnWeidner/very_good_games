import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/chromix/models/models.dart';
import 'package:very_good_games/games/chromix/view/widgets/color_bar.dart';

void main() {
  group('ColorBar', () {
    Widget buildSubject(Map<ChromixColor, int> distribution) {
      return MaterialApp(
        home: Scaffold(
          body: ColorBar(
            distribution: distribution,
            label: 'Test',
          ),
        ),
      );
    }

    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(buildSubject(const {}));

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('renders empty bar for empty distribution', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(const {}));

      // Should render without errors.
      expect(find.byType(ColorBar), findsOneWidget);
    });

    testWidgets('renders segments with count labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject({
          ChromixColor.red: 3,
          ChromixColor.blue: 2,
        }),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('renders all six colors when present', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject({
          ChromixColor.red: 1,
          ChromixColor.yellow: 1,
          ChromixColor.blue: 1,
          ChromixColor.orange: 1,
          ChromixColor.green: 1,
          ChromixColor.purple: 1,
        }),
      );

      // 6 segments with count "1".
      expect(find.text('1'), findsNWidgets(6));
    });
  });
}
