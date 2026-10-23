import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/olympiade/ausgabe_2026/darts/darts_models.dart';

DartsGame _game({int legsToWin = 3, List<int> legWinners = const []}) {
  return DartsGame(
    id: 'game1',
    createdBy: 'u1',
    date: DateTime(2026, 10, 22),
    playerUids: ['u1', 'u2'],
    playerNames: ['Theo', 'Max'],
    legsToWin: legsToWin,
    legs: legWinners.map((w) => DartsLeg(winnerIndex: w)).toList(),
  );
}

void main() {
  group('Darts Models and Logic Tests', () {
    test('counts legs per player', () {
      final game = _game(legWinners: [0, 1, 0]);
      expect(game.legsWon, [2, 1]);
      expect(game.winnerIndex, isNull);
    });

    test('reaching legsToWin decides the match', () {
      final game = _game(legWinners: [1, 0, 1, 1]);
      expect(game.legsWon, [1, 3]);
      expect(game.winnerIndex, 1);
    });

    test('legs after the match is decided are ignored', () {
      final game = _game(legsToWin: 2, legWinners: [0, 0, 1]);
      expect(game.winnerIndex, 0);
      expect(game.legsWon, [2, 0]);
      expect(game.countedLegs.length, 2);
    });

    test('DartsGame serializes and restores properly', () {
      final game = _game(legsToWin: 5, legWinners: [0, 1]);
      final restored = DartsGame.fromMap(game.toMap(), id: 'game1');
      expect(restored.playerNames, ['Theo', 'Max']);
      expect(restored.legsToWin, 5);
      expect(restored.legsWon, [1, 1]);
    });
  });
}
