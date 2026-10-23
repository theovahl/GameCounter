import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/olympiade/ausgabe_2026/rubiks/rubiks_models.dart';

RubiksGame _game({int winsNeeded = 2, List<int> roundWinners = const []}) {
  return RubiksGame(
    id: 'game1',
    createdBy: 'u1',
    date: DateTime(2026, 10, 22),
    memberUids: ['u1', 'u2', 'u3', 'u4'],
    teams: [
      RubiksTeam(name: 'Team 1', playerUids: ['u1', 'u2'], playerNames: ['Theo', 'Anna']),
      RubiksTeam(name: 'Team 2', playerUids: ['u3', 'u4'], playerNames: ['Max', 'Ben']),
    ],
    winsNeeded: winsNeeded,
    rounds: roundWinners.map((w) => RubiksRound(winnerIndex: w)).toList(),
  );
}

void main() {
  group('Rubiks Models and Logic Tests', () {
    test('counts won games per team', () {
      final game = _game(winsNeeded: 3, roundWinners: [0, 1, 0]);
      expect(game.wins, [2, 1]);
      expect(game.winnerIndex, isNull);
    });

    test('best of three is decided after two wins', () {
      final game = _game(roundWinners: [1, 0, 1]);
      expect(game.wins, [1, 2]);
      expect(game.winnerIndex, 1);
    });

    test('games after the best of is decided are ignored', () {
      final game = _game(roundWinners: [0, 0, 1]);
      expect(game.winnerIndex, 0);
      expect(game.wins, [2, 0]);
      expect(game.countedRounds.length, 2);
    });

    test('RubiksGame serializes and restores properly', () {
      final game = _game(winsNeeded: 4, roundWinners: [1, 0]);
      final restored = RubiksGame.fromMap(game.toMap(), id: 'game1');
      expect(restored.teams[0].playerNames, ['Theo', 'Anna']);
      expect(restored.winsNeeded, 4);
      expect(restored.wins, [1, 1]);
    });
  });
}
