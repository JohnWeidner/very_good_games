import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/cascade/cascade_game.dart';

class _MockGameStorageRepository extends Mock
    implements GameStorageRepository {}

void main() {
  group('CascadeGame', () {
    late CascadeGame game;

    setUp(() {
      game = CascadeGame(
        storageRepository: _MockGameStorageRepository(),
      );
    });

    test('id is cascade', () {
      expect(game.id, 'cascade');
    });

    test('name is Cascade', () {
      expect(game.name, 'Cascade');
    });

    test('has description', () {
      expect(game.description, isNotEmpty);
    });

    test('has icon', () {
      expect(game.icon, Icons.arrow_downward);
    });

    test('routePath is /games/cascade', () {
      expect(game.routePath, '/games/cascade');
    });

    test('routes is not empty', () {
      expect(game.routes, isNotEmpty);
    });
  });
}
