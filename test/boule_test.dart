import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/boule/boule_models.dart';

BouleGame _game({
  int teamCount = 2,
  int pointsPerSet = 13,
  int setsToWin = 1,
  List<List<int>> ends = const [],
}) {
  return BouleGame(
    id: 'game1',
    createdBy: 'u1',
    date: DateTime(2026, 10, 22),
    memberUids: ['u1', 'u2'],
    teams: List.generate(
      teamCount,
      (i) => BouleTeam(name: 'Team ${i + 1}', playerUids: ['u$i'], playerNames: ['P$i']),
    ),
    pointsPerSet: pointsPerSet,
    setsToWin: setsToWin,
    ends: ends.map((e) => BouleEnd(teamIndex: e[0], points: e[1])).toList(),
  );
}

void main() {
  group('Boule Models and Logic Tests', () {
    test('current set sums up points per team', () {
      final game = _game(ends: [[0, 3], [1, 2], [0, 4]]);
      expect(game.currentSet.scores, [7, 2]);
      expect(game.currentSet.setNumber, 1);
      expect(game.winnerTeam, isNull);
    });

    test('reaching the set target wins the game with one set', () {
      final game = _game(ends: [[0, 6], [1, 5], [0, 6], [0, 1]]);
      expect(game.winnerTeam, 0);
      expect(game.sets.length, 1);
      expect(game.sets.first.scores, [13, 5]);
    });

    test('best of three starts a new set after each won set', () {
      final game = _game(pointsPerSet: 5, setsToWin: 2, ends: [
        [0, 5], // Satz 1 -> Team 1
        [1, 3], [1, 2], // Satz 2 -> Team 2
        [0, 2], // Satz 3 läuft
      ]);
      expect(game.setsWon, [1, 1]);
      expect(game.winnerTeam, isNull);
      expect(game.currentSet.setNumber, 3);
      expect(game.currentSet.scores, [2, 0]);
      expect(game.sets[1].endIndices, [1, 2]);
    });

    test('ends after the match is decided are ignored', () {
      final game = _game(pointsPerSet: 5, ends: [[1, 5], [0, 3]]);
      expect(game.winnerTeam, 1);
      expect(game.sets.length, 1);
    });

    test('works with three teams', () {
      final game = _game(teamCount: 3, pointsPerSet: 7, ends: [[2, 4], [1, 3], [2, 3]]);
      expect(game.winnerTeam, 2);
      expect(game.sets.first.scores, [0, 3, 7]);
    });

    test('BouleGame serializes and restores properly', () {
      final game = _game(pointsPerSet: 11, setsToWin: 2, ends: [[0, 2], [1, 4]]);
      final restored = BouleGame.fromMap(game.toMap(), id: 'game1');
      expect(restored.teams.length, 2);
      expect(restored.teams[1].playerNames, ['P1']);
      expect(restored.pointsPerSet, 11);
      expect(restored.setsToWin, 2);
      expect(restored.ends.length, 2);
      expect(restored.currentSet.scores, [2, 4]);
    });
  });
}
