import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/games/guess_the_number/view/widgets/score_bar.dart';

void main() {
  group('ScoreBar', () {
    testWidgets('displays current score', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ScoreBar(score: 450))),
      );
      expect(find.text('450'), findsOneWidget);
    });

    testWidgets('displays max budget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ScoreBar(score: 300))),
      );
      expect(find.text('600'), findsOneWidget);
    });

    testWidgets('renders LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ScoreBar(score: 300))),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays zero score', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ScoreBar(score: 0))),
      );
      expect(find.text('0'), findsOneWidget);
    });
  });
}
