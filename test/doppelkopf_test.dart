import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/doppelkopf/doppelkopf_game_model.dart';

void main() {
  group('Doppelkopf Models and Logic Tests', () {
    test('GameRound toMap and fromMap works correctly', () {
      final round = GameRound(
        roundNumber: 1,
        scores: [3, 3, -3, -3],
        timestamp: DateTime(2026, 9, 3, 18, 0),
      );

      final map = round.toMap();
      expect(map['roundNumber'], 1);
      expect(map['scores'], [3, 3, -3, -3]);

      final restored = GameRound.fromMap(map);
      expect(restored.roundNumber, 1);
      expect(restored.scores, [3, 3, -3, -3]);
    });

    test('DoppelkopfGame calculates total scores correctly', () {
      final game = DoppelkopfGame(
        id: 'game123',
        groupId: 'group123',
        groupName: 'Stammtisch',
        createdBy: 'user1',
        date: DateTime.now(),
        playerUids: ['u1', 'u2', 'u3', 'u4'],
        playerNames: ['Theo', 'Max', 'Anna', 'Ben'],
        rounds: [
          GameRound(roundNumber: 1, scores: [3, 3, -3, -3]),
          GameRound(roundNumber: 2, scores: [-1, 3, -1, -1]),
        ],
      );

      expect(game.calculatedTotalScores, [2, 6, -4, -4]);
    });

    test('PlayerGroup serializes and restores properly', () {
      final group = PlayerGroup(
        id: 'group123',
        name: 'Donnerstag',
        createdBy: 'user1',
        playerUids: ['u1', 'u2', 'u3', 'u4'],
        playerNames: ['Theo', 'Max', 'Anna', 'Ben'],
        createdAt: DateTime(2026, 9, 3, 12, 0),
      );

      final map = group.toMap();
      expect(map['name'], 'Donnerstag');
      expect(map['createdBy'], 'user1');
      expect(map['playerUids'], ['u1', 'u2', 'u3', 'u4']);
      expect(map['playerNames'], ['Theo', 'Max', 'Anna', 'Ben']);

      final restored = PlayerGroup.fromMap(map, id: 'group123');
      expect(restored.id, 'group123');
      expect(restored.name, 'Donnerstag');
      expect(restored.playerUids.length, 4);
    });
  });
}

