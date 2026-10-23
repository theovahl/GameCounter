import 'core/olympiade_edition.dart';
import 'ausgabe_2026/ausgabe_2026.dart';

// Alle Ausgaben der WG Olympiade, neueste zuerst.
//
// Neue Ausgabe einpflegen:
//   1. Ordner der letzten Ausgabe kopieren (z.B. ausgabe_2026 -> ausgabe_2027)
//   2. Darin id, year, number, Regeln, Zeitplan und Disziplinen anpassen
//      (die Spielmodi im Ordner gehören nur zu dieser Ausgabe und dürfen frei geändert werden)
//   3. Die neue Ausgabe hier oben in die Liste eintragen
// Olympiaden speichern die id ihrer Ausgabe; ältere ohne id gehören zu [olympiadeDefaultEditionId].
const List<OlympiadeEdition> olympiadeEditions = [
  ausgabe2026,
];

const String olympiadeDefaultEditionId = '2026-4';

OlympiadeEdition olympiadeEditionById(String? id) {
  for (final edition in olympiadeEditions) {
    if (edition.id == id) return edition;
  }
  return olympiadeEditions.firstWhere(
    (e) => e.id == olympiadeDefaultEditionId,
    orElse: () => olympiadeEditions.first,
  );
}
