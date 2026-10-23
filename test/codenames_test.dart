import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/olympiade/ausgabe_2026/codenames/codenames_models.dart';

CodenamesGame _game({int winsNeeded = 3, List<int> roundWinners = const []}) {
  return CodenamesGame(
    id: 'game1',
    createdBy: 'u1',
    date: DateTime(2026, 10, 22),
    memberUids: ['u1', 'u2', 'u3', 'u4'],
    teams: [
      CodenamesTeam(name: 'Team Rot', playerUids: ['u1', 'u2'], playerNames: ['Theo', 'Anna']),
      CodenamesTeam(name: 'Team Blau', playerUids: ['u3', 'u4'], playerNames: ['Max', 'Ben']),
    ],
    winsNeeded: winsNeeded,
    rounds: roundWinners.map((w) => CodenamesRound(winnerIndex: w)).toList(),
  );
}

void main() {
  group('Codenames Models and Logic Tests', () {
    test('counts wins per team', () {
      final game = _game(roundWinners: [0, 1, 1]);
      expect(game.wins, [1, 2]);
      expect(game.winnerIndex, isNull);
    });

    test('reaching winsNeeded decides the match', () {
      final game = _game(roundWinners: [0, 1, 0, 0]);
      expect(game.wins, [3, 1]);
      expect(game.winnerIndex, 0);
    });

    test('rounds after the match is decided are ignored', () {
      final game = _game(winsNeeded: 1, roundWinners: [1, 0]);
      expect(game.winnerIndex, 1);
      expect(game.wins, [0, 1]);
      expect(game.countedRounds.length, 1);
    });

    test('CodenamesGame serializes and restores properly', () {
      final game = _game(winsNeeded: 2, roundWinners: [1]);
      final restored = CodenamesGame.fromMap(game.toMap(), id: 'game1');
      expect(restored.teams.length, 2);
      expect(restored.teams[0].playerNames, ['Theo', 'Anna']);
      expect(restored.teams[1].name, 'Team Blau');
      expect(restored.winsNeeded, 2);
      expect(restored.wins, [0, 1]);
    });
  });
}
