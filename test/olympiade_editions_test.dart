import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/olympiade/ausgabe_2026/halbieren/halbieren_discipline.dart';
import 'package:game_counter/olympiade/core/olympiade_discipline.dart';
import 'package:game_counter/olympiade/core/olympiade_models.dart';
import 'package:game_counter/olympiade/olympiade_editions.dart';

void main() {
  group('Olympiade editions', () {
    test('edition ids are unique and the default edition exists', () {
      final ids = olympiadeEditions.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, contains(olympiadeDefaultEditionId));
    });

    // Schützt neue Ausgaben vor Tippfehlern bei Disziplin-Schlüsseln und Uhrzeiten
    for (final edition in olympiadeEditions) {
      test('${edition.label}: rules and schedule only reference its own disciplines', () {
        final keys = edition.disciplineKeys;
        expect(keys.toSet().length, keys.length, reason: 'Schlüssel doppelt');
        for (final d in edition.disciplines) {
          expect(d, isNot(isA<UnknownOlympiadeDiscipline>()));
          for (final s in d.settings) {
            expect(s.presets.every((p) => p >= s.min && p <= s.max), isTrue, reason: '${d.key}.${s.key}');
            expect(s.defaultValue, inInclusiveRange(s.min, s.max), reason: '${d.key}.${s.key}');
          }
        }
        for (final section in edition.rules) {
          expect(keys, contains(section.discipline));
          expect(section.items, isNotEmpty);
        }
        for (final day in edition.schedule) {
          for (final entry in day.entries) {
            if (entry.discipline != null) expect(keys, contains(entry.discipline));
            expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(entry.start), isTrue, reason: entry.title);
            expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(entry.end), isTrue, reason: entry.title);
          }
        }
      });
    }

    test('2026 edition: nine disciplines with the settings of the rulebook', () {
      final edition = olympiadeEditionById('2026-4');
      expect(edition.label, '4. Ausgabe 2026');
      expect(edition.rules.length, 9);
      expect(edition.schedule.map((d) => d.name), ['Freitag', 'Samstag', 'Sonntag']);
      expect(edition.disciplineKeys, [
        'darts', 'halbieren', 'mariokart', 'geoguessr', 'rubiks', 'basketball', 'codenames', 'boule', 'bierpong',
      ]);

      int defaultOf(String discipline, String setting) =>
          edition.discipline(discipline).settings.firstWhere((s) => s.key == setting).defaultValue;
      expect(defaultOf('darts', 'legsToWin'), 3); // BO5
      expect(defaultOf('codenames', 'winsNeeded'), 3); // BO5
      expect(defaultOf('basketball', 'winsNeeded'), 2); // BO3
      expect(defaultOf('rubiks', 'winsNeeded'), 1);
      expect(defaultOf('boule', 'pointsPerSet'), 15);
      expect(defaultOf('boule', 'setsToWin'), 2);

      final teilen = edition.discipline('halbieren') as TeilenOlympiadeDiscipline;
      expect(teilen.foods.length, 9);
      expect(teilen.foods[3].actNote, 'Nur schwache Hand');
      expect(edition.discipline('darts').roundRobinRounds, 1);
      expect(edition.discipline('bierpong').roundRobinRounds, 2);
    });

    test('olympiaden remember their edition, unknown or missing ids fall back to the default', () {
      final olympiade = OlympiadeGame(
        editionId: '2026-4',
        createdBy: 'u1',
        date: DateTime(2026, 10, 23),
        memberUids: ['u1'],
        wgs: [
          OlympiadeWg(name: 'A', playerUids: ['u1'], playerNames: ['Theo']),
          OlympiadeWg(name: 'B', playerUids: ['u2'], playerNames: ['Max']),
        ],
        disciplines: ['darts'],
      );
      final restored = OlympiadeGame.fromMap(olympiade.toMap(), id: 'o1');
      expect(restored.editionId, '2026-4');
      expect(restored.copyWithResult('darts', const OlympiadeResult()).editionId, '2026-4');

      final older = OlympiadeGame.fromMap(olympiade.toMap()..remove('editionId'), id: 'o2');
      expect(older.editionId, olympiadeDefaultEditionId);
      expect(older.edition.id, olympiadeDefaultEditionId);

      // Kurzzeitig verwendete alte Kennung landet ebenfalls bei der 4. Ausgabe 2026
      final legacy = OlympiadeGame.fromMap({...olympiade.toMap(), 'editionId': '2026-2'}, id: 'o3');
      expect(legacy.edition.id, '2026-4');

      // Ohne gespeicherte Disziplinen gelten die der Ausgabe
      final noDisciplines = OlympiadeGame.fromMap(olympiade.toMap()..remove('disciplines'), id: 'o4');
      expect(noDisciplines.disciplines, olympiadeEditionById('2026-4').disciplineKeys);
    });
  });
}
