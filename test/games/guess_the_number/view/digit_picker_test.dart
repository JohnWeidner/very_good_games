import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/guess_the_number/view/widgets/digit_picker.dart';

void main() {
  group('DigitPicker', () {
    testWidgets('renders digits 0 through 9', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DigitPicker(onDigitSelected: (_) {}),
          ),
        ),
      );
      for (var i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('calls onDigitSelected when tapped', (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DigitPicker(
              onDigitSelected: (d) => selected = d,
            ),
          ),
        ),
      );
      await tester.tap(find.text('7'));
      expect(selected, equals(7));
    });

    testWidgets('highlights selected digit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DigitPicker(
              selectedDigit: 3,
              onDigitSelected: (_) {},
            ),
          ),
        ),
      );
      // The selected digit's Material should use the primary color.
      final materials = tester.widgetList<Material>(
        find.byType(Material),
      );
      // Find the Material wrapping digit 3 — it should use primary.
      final theme = Theme.of(
        tester.element(find.text('3')),
      );
      final selectedMaterial = materials.where(
        (m) => m.color == theme.colorScheme.primary,
      );
      expect(selectedMaterial, isNotEmpty);
    });
  });
}
