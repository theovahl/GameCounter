import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/olympiade/ausgabe_2026/halbieren/halbieren_models.dart';

HalbierenGame _game({List<TeilenEntry> entries = const [], String status = 'active'}) {
  return HalbierenGame(
    id: 'game1',
    createdBy: 'u1',
    date: DateTime(2026, 10, 23),
    memberUids: ['u1', 'u2', 'u3', 'u4'],
    teams: [
      HalbierenTeam(name: 'Unsere WG', playerUids: ['u1', 'u2'], playerNames: ['Theo', 'Anna']),
      HalbierenTeam(name: 'Gegner-WG', playerUids: ['u3', 'u4'], playerNames: ['Max', 'Ben']),
    ],
    foods: [
      TeilenFood(act: 0, actTitle: 'Erster Akt', name: 'Ei'),
      TeilenFood(act: 0, actTitle: 'Erster Akt', name: 'Banane'),
      TeilenFood(act: 1, actTitle: 'Zweiter Akt', actNote: 'Nur schwache Hand', name: 'Apfel'),
    ],
    entries: entries,
    status: status,
  );
}

TeilenEntry _entry(int food, int team, double deviation, [String? cutter]) =>
    TeilenEntry(foodIndex: food, teamIndex: team, deviation: deviation, cutterUid: cutter);

void main() {
  group('Das Große Teilen', () {
    test('sums up deviations per team and finds the current food', () {
      final game = _game(entries: [_entry(0, 0, 4.5), _entry(0, 1, 2.0), _entry(1, 0, 1.5)]);
      expect(game.totals, [6.0, 2.0]);
      expect(game.isFoodDone(0), isTrue);
      expect(game.isFoodDone(1), isFalse);
      expect(game.currentFoodIndex, 1);
      expect(game.doneCount, 1);
      expect(game.winnerIndex, isNull);
    });

    test('the smaller total deviation wins once every food is done', () {
      final game = _game(entries: [
        _entry(0, 0, 3), _entry(0, 1, 5),
        _entry(1, 0, 2), _entry(1, 1, 1),
        _entry(2, 0, 4), _entry(2, 1, 6),
      ]);
      expect(game.isComplete, isTrue);
      expect(game.totals, [9.0, 12.0]);
      expect(game.winnerIndex, 0);
    });

    test('equal totals are a draw', () {
      final game = _game(entries: [
        _entry(0, 0, 3), _entry(0, 1, 3),
        _entry(1, 0, 2), _entry(1, 1, 2),
        _entry(2, 0, 1), _entry(2, 1, 1),
      ]);
      expect(game.isComplete, isTrue);
      expect(game.winnerIndex, isNull);
    });

    test('tracks who already cut in an act', () {
      final game = _game(entries: [_entry(0, 0, 3, 'u1'), _entry(1, 0, 2, 'u2'), _entry(2, 0, 1, 'u1')]);
      expect(game.cuttersInAct(0, 0), {'u1', 'u2'});
      expect(game.cuttersInAct(1, 0), {'u1'});
      expect(game.cuttersInAct(0, 1), isEmpty);
    });

    test('serializes and restores foods and entries', () {
      final game = _game(entries: [_entry(2, 1, 7.25, 'u3')]);
      final restored = HalbierenGame.fromMap(game.toMap(), id: 'game1');
      expect(restored.foods.map((f) => f.name), ['Ei', 'Banane', 'Apfel']);
      expect(restored.foods[2].actNote, 'Nur schwache Hand');
      expect(restored.entryFor(2, 1)?.deviation, 7.25);
      expect(restored.entryFor(2, 1)?.cutterUid, 'u3');
    });

    test('formats percentages with a comma', () {
      expect(formatTeilenPercent(4.25), '4,3 %');
      expect(formatTeilenPercent(0), '0,0 %');
    });
  });
}
