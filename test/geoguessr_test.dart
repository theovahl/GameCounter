import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/olympiade/ausgabe_2026/geoguessr/geoguessr_models.dart';

GeoguessrGame _game(List<List<int>> rounds) {
  return GeoguessrGame(
    id: 'game1',
    createdBy: 'u1',
    date: DateTime(2026, 10, 23),
    memberUids: ['u1', 'u2'],
    teams: [
      GeoguessrTeam(name: 'Unsere WG', playerUids: ['u1'], playerNames: ['Theo']),
      GeoguessrTeam(name: 'Gegner-WG', playerUids: ['u2'], playerNames: ['Max']),
    ],
    stages: [
      GeoguessrStage(title: 'Weltkarte · Bewegen'),
      GeoguessrStage(title: 'Weltkarte · No-Move'),
      GeoguessrStage(title: 'Deutschland · Bewegen'),
    ],
    // [Stufe, Gewinner]
    rounds: rounds.map((r) => GeoguessrRound(stageIndex: r[0], winnerIndex: r[1])).toList(),
  );
}

void main() {
  group('GeoGuessr stages', () {
    test('each stage is a best of three, then the next stage starts', () {
      final game = _game([[0, 0], [0, 1], [0, 0], [1, 1]]);
      expect(game.stageWins(0), [2, 1]);
      expect(game.isStageDone(0), isTrue);
      expect(game.currentStageIndex, 1);
      expect(game.wins, [2, 2]);
      expect(game.winnerIndex, isNull);
    });

    test('rounds after a stage is decided do not count', () {
      final game = _game([[0, 1], [0, 1], [0, 0]]);
      expect(game.stageWins(0), [0, 2]);
      expect(game.countedRounds.length, 2);
    });

    test('total rounds across all stages decide the winner', () {
      // 2:1, 0:2, 2:0 -> 4:3 Runden
      final game = _game([
        [0, 0], [0, 1], [0, 0],
        [1, 1], [1, 1],
        [2, 0], [2, 0],
      ]);
      expect(game.isComplete, isTrue);
      expect(game.wins, [4, 3]);
      expect(game.winnerIndex, 0);
    });

    test('fewer stage wins can still win on total rounds', () {
      // 2:1, 1:2, 1:2 -> Team 2 gewinnt zwei Stufen und hat 5:4 Runden
      final game = _game([
        [0, 0], [0, 1], [0, 0],
        [1, 1], [1, 0], [1, 1],
        [2, 0], [2, 1], [2, 1],
      ]);
      expect(game.isComplete, isTrue);
      expect(game.wins, [4, 5]);
      expect(game.winnerIndex, 1);
    });

    test('equal total rounds are a draw', () {
      // 2:1, 2:1, 0:2 -> 4:4 Runden
      final game = _game([
        [0, 0], [0, 1], [0, 0],
        [1, 1], [1, 0], [1, 0],
        [2, 1], [2, 1],
      ]);
      expect(game.isComplete, isTrue);
      expect(game.wins, [4, 4]);
      expect(game.winnerIndex, isNull);
    });

    test('serializes stages and rounds', () {
      final game = _game([[0, 1], [1, 0]]);
      final restored = GeoguessrGame.fromMap(game.toMap(), id: 'game1');
      expect(restored.stages.map((s) => s.title), ['Weltkarte · Bewegen', 'Weltkarte · No-Move', 'Deutschland · Bewegen']);
      expect(restored.rounds[1].stageIndex, 1);
      expect(restored.wins, [1, 1]);
    });

    test('older games without stages become a single best-of stage', () {
      final restored = GeoguessrGame.fromMap({
        'teams': [],
        'winsNeeded': 3,
        'rounds': [
          {'winnerIndex': 0},
          {'winnerIndex': 0},
          {'winnerIndex': 0},
        ],
      }, id: 'old');
      expect(restored.stages.length, 1);
      expect(restored.stages.first.winsNeeded, 3);
      expect(restored.isComplete, isTrue);
      expect(restored.winnerIndex, 0);
    });
  });
}
