import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/olympiade/ausgabe_2026/bierpong/bierpong_models.dart';

BierpongGame _game(String opponentUid, String opponentName, int winnerIndex) {
  return BierpongGame(
    createdBy: 'me',
    date: DateTime(2026, 10, 22),
    playerUids: ['me', opponentUid],
    playerNames: ['Theo', opponentName],
    winnerIndex: winnerIndex,
  );
}

void main() {
  group('Bierpong Models and Logic Tests', () {
    test('BierpongGame serializes and restores properly', () {
      final game = _game('u2', 'Max', 1);
      final restored = BierpongGame.fromMap(game.toMap(), id: 'g1');
      expect(restored.id, 'g1');
      expect(restored.playerNames, ['Theo', 'Max']);
      expect(restored.winnerIndex, 1);
      expect(restored.winnerName, 'Max');
      expect(restored.winnerUid, 'u2');
    });

    test('records are calculated per opponent and sorted by games played', () {
      final games = [
        _game('u2', 'Max', 0),
        _game('u3', 'Anna', 1),
        _game('u2', 'Max', 1),
        _game('u2', 'Max', 0),
      ];
      final records = bierpongRecordsFor('me', games);
      expect(records.length, 2);
      expect(records[0].opponentName, 'Max');
      expect(records[0].wins, 2);
      expect(records[0].losses, 1);
      expect(records[1].opponentName, 'Anna');
      expect(records[1].wins, 0);
      expect(records[1].losses, 1);
    });

    test('records work when the user is the second player', () {
      final game = BierpongGame(
        createdBy: 'u2',
        date: DateTime(2026, 10, 22),
        playerUids: ['u2', 'me'],
        playerNames: ['Max', 'Theo'],
        winnerIndex: 1,
      );
      final records = bierpongRecordsFor('me', [game]);
      expect(records.single.opponentName, 'Max');
      expect(records.single.wins, 1);
    });
  });
}
