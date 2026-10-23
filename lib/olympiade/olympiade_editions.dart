// Ausgaben der WG Olympiade mit Regelwerk und Zeitplan.
//
// Neue Ausgabe einpflegen: unten in [olympiadeEditions] einen weiteren
// OlympiadeEdition-Eintrag ergänzen (neueste zuerst). Olympiaden speichern die
// editionId, ältere Olympiaden ohne editionId gehören zu [olympiadeDefaultEditionId].

// Ein Regelpunkt, optional mit Unterpunkten
class OlympiadeRuleItem {
  final String text;
  final List<OlympiadeRuleItem> children;

  const OlympiadeRuleItem(this.text, [this.children = const []]);
}

// Regeln einer Disziplin
class OlympiadeRuleSection {
  final String discipline; // Schlüssel aus olympiadeAllDisciplines (für Icon & Farbe)
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

// Ein Akt beim Großen Teilen: mehrere Lebensmittel mit einer gemeinsamen Erschwernis
class OlympiadeTeilenAct {
  final String title; // "Erster Akt"
  final String? note; // z.B. "Nur schwache Hand"
  final List<String> foods;

  const OlympiadeTeilenAct({required this.title, this.note, required this.foods});
}

// Eine Stufe bei GeoGuessr (jeweils Best of)
class OlympiadeGeoStage {
  final String title; // "Weltkarte · Bewegen"
  final String details; // "2 Minuten pro Runde, Team-Durchschnitt"
  final int winsNeeded; // 2 = BO3

  const OlympiadeGeoStage({required this.title, required this.details, this.winsNeeded = 2});
}

class OlympiadeEdition {
  final String id;
  final int year;
  final int number; // Laufende Nummer der Ausgabe
  final List<String> disciplines; // Vorauswahl beim Anlegen einer Olympiade
  final List<OlympiadeRuleSection> rules;
  final List<OlympiadeScheduleDay> schedule;
  // Vorbelegte Einstellungen beim Starten einer Disziplin: Disziplin -> Einstellung -> Wert
  final Map<String, Map<String, int>> settingDefaults;
  // Jeder gegen jeden: Disziplin -> wie oft jede Paarung gespielt wird (Dart 1, Bierpong 2)
  final Map<String, int> roundRobin;
  // Das Große Teilen: Akte mit Lebensmitteln und Zeit pro Lebensmittel
  final List<OlympiadeTeilenAct> teilenActs;
  final int teilenSecondsPerFood;
  // GeoGuessr: Stufen, deren gewonnene Runden zusammengezählt werden
  final List<OlympiadeGeoStage> geoguessrStages;

  const OlympiadeEdition({
    required this.id,
    required this.year,
    required this.number,
    required this.disciplines,
    required this.rules,
    required this.schedule,
    this.settingDefaults = const {},
    this.roundRobin = const {},
    this.teilenActs = const [],
    this.teilenSecondsPerFood = 180,
    this.geoguessrStages = const [],
  });

  String get title => 'WG Olympiade $year';
  String get label => '$number. Ausgabe $year';

  OlympiadeRuleSection? rulesFor(String discipline) {
    for (final section in rules) {
      if (section.discipline == discipline) return section;
    }
    return null;
  }

  int? settingDefault(String discipline, String setting) => settingDefaults[discipline]?[setting];
}

const String olympiadeDefaultEditionId = '2026-4';

// Alle Ausgaben, neueste zuerst
const List<OlympiadeEdition> olympiadeEditions = [
  OlympiadeEdition(
    id: '2026-4',
    year: 2026,
    number: 4,
    disciplines: [
      'darts',
      'halbieren',
      'mariokart',
      'geoguessr',
      'rubiks',
      'basketball',
      'codenames',
      'boule',
      'bierpong',
    ],
    settingDefaults: {
      'darts': {'legsToWin': 3}, // BO5
      'codenames': {'winsNeeded': 3}, // BO5
      'boule': {'pointsPerSet': 15, 'setsToWin': 2}, // BO3 bis 15
      'basketball': {'winsNeeded': 2}, // BO3
      'rubiks': {'winsNeeded': 1}, // ein Durchgang, wer zuerst fertig ist
    },
    roundRobin: {
      'darts': 1, // jeder gegen jeden
      'bierpong': 2, // jeder gegen jeden, Hin- und Rückrunde
    },
    teilenSecondsPerFood: 180,
    teilenActs: [
      OlympiadeTeilenAct(title: 'Erster Akt', foods: ['Hartgekochtes Ei', 'Banane', 'Gurke']),
      OlympiadeTeilenAct(
        title: 'Zweiter Akt',
        note: 'Nur schwache Hand',
        foods: ['Ingwerknolle', 'Apfel', 'Brötchen'],
      ),
      OlympiadeTeilenAct(
        title: 'Dritter Akt',
        note: 'Wer zerteilt, hat die Augen verbunden',
        foods: ['Toast', 'Wasser', 'Paprika'],
      ),
    ],
    geoguessrStages: [
      OlympiadeGeoStage(
        title: 'Weltkarte · Bewegen',
        details: '2 Minuten pro Runde, Team-Durchschnitt',
      ),
      OlympiadeGeoStage(
        title: 'Weltkarte · No-Move',
        details: 'No-Move (Ehrensache), 2 Minuten pro Runde, bester Tipp',
      ),
      OlympiadeGeoStage(
        title: 'Deutschland · Bewegen',
        details: '30 Sekunden pro Runde, Team-Durchschnitt',
      ),
    ],
    rules: [
      OlympiadeRuleSection(
        discipline: 'darts',
        title: 'Dart',
        items: [
          OlympiadeRuleItem('BO5, 301, Single Out'),
          OlympiadeRuleItem('Jeder gegen jeden → 9 Matches'),
          OlympiadeRuleItem('Am Ende werden die Legs gezählt'),
        ],
      ),
      OlympiadeRuleSection(
        discipline: 'halbieren',
        title: 'Das Große Teilen',
        items: [
          OlympiadeRuleItem(
            'Format: In jedem Akt muss jeder einmal zerteilen. Am Ende werden die '
            'Gesamtabweichungen in Prozent aufsummiert und verglichen. Man hat '
            '3 Minuten Zeit pro Lebensmittel.',
          ),
          OlympiadeRuleItem('Erster Akt', [
            OlympiadeRuleItem('Hartgekochtes Ei, Banane, Gurke'),
          ]),
          OlympiadeRuleItem('Zweiter Akt: nur schwache Hand', [
            OlympiadeRuleItem('Ingwerknolle, Apfel, Brötchen'),
          ]),
          OlympiadeRuleItem('Dritter Akt: Wer zerteilt, hat die Augen verbunden', [
            OlympiadeRuleItem('Toast'),
            OlympiadeRuleItem(
              'Wasser: zufällige Zahl zwischen 100 und 800, diese Menge genau in einen '
              'Topf unter dem Wasserhahn abfüllen',
            ),
            OlympiadeRuleItem('Paprika'),
          ]),
        ],
      ),
      OlympiadeRuleSection(
        discipline: 'mariokart',
        title: 'Mario Kart',
        items: [
          OlympiadeRuleItem('Alle 48 Strecken'),
          OlympiadeRuleItem('Ohne Teams, Gesamtwertung'),
        ],
      ),
      OlympiadeRuleSection(
        discipline: 'geoguessr',
        title: 'GeoGuessr',
        items: [
          OlympiadeRuleItem('WorldGuessr: drei Runden', [
            OlympiadeRuleItem('BO3: Weltkarte, Bewegen, 2 Minuten pro Runde, Team-Durchschnitt'),
            OlympiadeRuleItem('BO3: Weltkarte, No-Move (Ehrensache), 2 Minuten pro Runde, bester Tipp'),
            OlympiadeRuleItem('BO3: Deutschland, 30 Sekunden, Bewegen, Team-Durchschnitt'),
          ]),
          OlympiadeRuleItem('Gezählt wird die Gesamtzahl der Runden'),
        ],
      ),
      OlympiadeRuleSection(
        discipline: 'rubiks',
        title: "Rubik's Cube Action",
        items: [
          OlympiadeRuleItem('Einer hält den Würfel und kann nicht sehen'),
          OlympiadeRuleItem('Einer darf den Würfel sehen, aber nicht sprechen'),
          OlympiadeRuleItem('Einer kann den Würfel nicht sehen und nichts hören, aber sprechen'),
          OlympiadeRuleItem('Beide WGs lösen gleichzeitig, die WG, die zuerst fertig ist, gewinnt'),
        ],
      ),
      OlympiadeRuleSection(
        discipline: 'basketball',
        title: 'Basketball Zerfetzung',
        items: [
          OlympiadeRuleItem('BO3: Die WG, die zuerst 2 Runden gewinnt, gewinnt'),
          OlympiadeRuleItem('Pro Runde', [
            OlympiadeRuleItem('Draft-Modus, in dem die Reihenfolge gedraftet wird'),
            OlympiadeRuleItem('Schnick Schnack Schnuck, wer anfangen muss'),
            OlympiadeRuleItem('Jeder versucht, bis 33 zu kommen'),
            OlympiadeRuleItem('Bei einem Airball landet man wieder bei 0'),
          ]),
        ],
      ),
      OlympiadeRuleSection(
        discipline: 'codenames',
        title: 'Codenames',
        items: [
          OlympiadeRuleItem('BO5'),
        ],
      ),
      OlympiadeRuleSection(
        discipline: 'boule',
        title: 'Boule',
        items: [
          OlympiadeRuleItem('BO3, jeweils bis 15'),
          OlympiadeRuleItem(
            'Das Team, das die nächsten x Kugeln an der Holzkugel hat, bekommt x Punkte',
          ),
        ],
      ),
      OlympiadeRuleSection(
        discipline: 'bierpong',
        title: 'Bierpong',
        items: [
          OlympiadeRuleItem('Jeder gegen jeden'),
          OlympiadeRuleItem('Hin- und Rückrunde'),
          OlympiadeRuleItem('Zwei Tische'),
        ],
      ),
    ],
    schedule: [
      OlympiadeScheduleDay(name: 'Freitag', entries: [
        OlympiadeScheduleEntry(start: '20:00', end: '22:00', title: 'Dart: 3 Matches', discipline: 'darts'),
      ]),
      OlympiadeScheduleDay(name: 'Samstag', entries: [
        OlympiadeScheduleEntry(start: '09:00', end: '11:00', title: 'Frühstücken'),
        OlympiadeScheduleEntry(start: '11:00', end: '13:00', title: 'Boule', discipline: 'boule'),
        OlympiadeScheduleEntry(start: '13:30', end: '15:00', title: 'Basketball', discipline: 'basketball'),
        OlympiadeScheduleEntry(start: '15:30', end: '16:15', title: "Rubik's Cube", discipline: 'rubiks'),
        OlympiadeScheduleEntry(start: '16:30', end: '17:30', title: 'GeoGuessr', discipline: 'geoguessr'),
        OlympiadeScheduleEntry(start: '17:30', end: '20:00', title: 'Dart', discipline: 'darts'),
        OlympiadeScheduleEntry(start: '20:30', end: '24:00', title: 'Bierpong', discipline: 'bierpong'),
      ]),
      OlympiadeScheduleDay(name: 'Sonntag', entries: [
        OlympiadeScheduleEntry(start: '09:00', end: '11:00', title: 'Frühstücken'),
        OlympiadeScheduleEntry(start: '11:00', end: '14:00', title: 'Mario Kart', discipline: 'mariokart'),
        OlympiadeScheduleEntry(start: '14:00', end: '15:00', title: 'Das Große Teilen', discipline: 'halbieren'),
        OlympiadeScheduleEntry(start: '15:00', end: '16:30', title: 'Codenames mit Pizza :D', discipline: 'codenames'),
      ]),
    ],
  ),
];

OlympiadeEdition olympiadeEditionById(String? id) {
  for (final edition in olympiadeEditions) {
    if (edition.id == id) return edition;
  }
  return olympiadeEditions.firstWhere(
    (e) => e.id == olympiadeDefaultEditionId,
    orElse: () => olympiadeEditions.first,
  );
}
