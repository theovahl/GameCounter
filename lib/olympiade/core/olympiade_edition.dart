import 'olympiade_discipline.dart';

// Bausteine einer Ausgabe der WG Olympiade. Die Ausgaben selbst liegen in eigenen
// Ordnern (z.B. lib/olympiade/ausgabe_2026/) und werden in
// lib/olympiade/olympiade_editions.dart aufgelistet.

// Ein Regelpunkt, optional mit Unterpunkten
class OlympiadeRuleItem {
  final String text;
  final List<OlympiadeRuleItem> children;

  const OlympiadeRuleItem(this.text, [this.children = const []]);
}

// Regeln einer Disziplin
class OlympiadeRuleSection {
  final String discipline; // Schlüssel der Disziplin (für Icon & Farbe)
  final String title;
  final List<OlympiadeRuleItem> items;

  const OlympiadeRuleSection({
    required this.discipline,
    required this.title,
    required this.items,
  });
}

// Ein Programmpunkt im Zeitplan
class OlympiadeScheduleEntry {
  final String start; // "11:00"
  final String end; // "13:00"
  final String title;
  final String? discipline; // null = kein Wettkampf (z.B. Frühstück)

  const OlympiadeScheduleEntry({
    required this.start,
    required this.end,
    required this.title,
    this.discipline,
  });
}

class OlympiadeScheduleDay {
  final String name; // "Samstag"
  final List<OlympiadeScheduleEntry> entries;

  const OlympiadeScheduleDay({required this.name, required this.entries});
}

class OlympiadeEdition {
  final String id; // Wird in jeder Olympiade gespeichert – nie ändern!
  final int year;
  final int number; // Laufende Nummer der Ausgabe
  final List<OlympiadeDiscipline> disciplines; // In Anzeigereihenfolge
  final List<OlympiadeRuleSection> rules;
  final List<OlympiadeScheduleDay> schedule;

  const OlympiadeEdition({
    required this.id,
    required this.year,
    required this.number,
    required this.disciplines,
    required this.rules,
    required this.schedule,
  });

  String get title => 'WG Olympiade $year';
  String get label => '$number. Ausgabe $year';

  List<String> get disciplineKeys => disciplines.map((d) => d.key).toList();

  /// Disziplin dieser Ausgabe (unbekannte Schlüssel ergeben einen Platzhalter)
  OlympiadeDiscipline discipline(String key) {
    for (final d in disciplines) {
      if (d.key == key) return d;
    }
    return UnknownOlympiadeDiscipline(key);
  }

  OlympiadeRuleSection? rulesFor(String discipline) {
    for (final section in rules) {
      if (section.discipline == discipline) return section;
    }
    return null;
  }
}
