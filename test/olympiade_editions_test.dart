import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/olympiade/olympiade_disciplines.dart';
import 'package:game_counter/olympiade/olympiade_editions.dart';
import 'package:game_counter/olympiade/olympiade_models.dart';

void main() {
  group('Olympiade editions', () {
    test('edition ids are unique and the default edition exists', () {
      final ids = olympiadeEditions.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, contains(olympiadeDefaultEditionId));
    });

    // Schützt neue Ausgaben vor Tippfehlern bei den Disziplin-Schlüsseln und Einstellungen
    for (final edition in olympiadeEditions) {
      test('${edition.label} only references known disciplines and settings', () {
        for (final d in edition.disciplines) {
          expect(olympiadeAllDisciplines, contains(d));
        }
        for (final section in edition.rules) {
          expect(olympiadeAllDisciplines, contains(section.discipline));
          expect(section.items, isNotEmpty);
        }
        for (final day in edition.schedule) {
          for (final entry in day.entries) {
            if (entry.discipline != null) expect(olympiadeAllDisciplines, contains(entry.discipline));
            expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(entry.start), isTrue, reason: entry.title);
            expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(entry.end), isTrue, reason: entry.title);
          }
        }
        edition.settingDefaults.forEach((discipline, settings) {
          final known = olympiadeDiscipline(discipline).settings.map((s) => s.key);
          for (final key in settings.keys) {
            expect(known, contains(key), reason: '$discipline.$key');
          }
        });
      });
    }

    test('2026 edition has rules for all nine disciplines and a three-day schedule', () {
      final edition = olympiadeEditionById('2026-4');
      expect(edition.label, '4. Ausgabe 2026');
      expect(edition.rules.length, 9);
      expect(edition.schedule.map((d) => d.name), ['Freitag', 'Samstag', 'Sonntag']);
      expect(edition.rulesFor('halbieren')?.title, 'Das Große Teilen');
      expect(edition.settingDefault('darts', 'legsToWin'), 3);
      expect(edition.settingDefault('codenames', 'winsNeeded'), 3);
    });

    test('olympiaden remember their edition, older ones fall back to the default', () {
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
    });
  });
}
