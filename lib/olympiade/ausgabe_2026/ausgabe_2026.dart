import 'package:game_counter/olympiade/core/olympiade_edition.dart';
import 'mariokart/mariokart_discipline.dart';
import 'boule/boule_discipline.dart';
import 'darts/darts_discipline.dart';
import 'codenames/codenames_discipline.dart';
import 'halbieren/halbieren_discipline.dart';
import 'bierpong/bierpong_discipline.dart';
import 'basketball/basketball_discipline.dart';
import 'geoguessr/geoguessr_discipline.dart';
import 'rubiks/rubiks_discipline.dart';

// WG Olympiade 2026 – 4. Ausgabe
//
// Dieser Ordner enthält alles, was zu dieser Ausgabe gehört: die Disziplinen
// (eigene Kopien der Spielmodi samt Olympiade-Anbindung), das Regelwerk und den Zeitplan.
// Für eine neue Ausgabe den Ordner kopieren, anpassen und in
// lib/olympiade/olympiade_editions.dart eintragen.
const OlympiadeEdition ausgabe2026 = OlympiadeEdition(
  id: '2026-4', // In den Olympiaden gespeichert – nicht ändern!
  year: 2026,
  number: 4,
  disciplines: [
    DartsOlympiadeDiscipline(),
    TeilenOlympiadeDiscipline(
      secondsPerFood: 180,
      acts: [
        TeilenAct(title: 'Erster Akt', foods: ['Hartgekochtes Ei', 'Banane', 'Gurke']),
        TeilenAct(
          title: 'Zweiter Akt',
          note: 'Nur schwache Hand',
          foods: ['Ingwerknolle', 'Apfel', 'Brötchen'],
        ),
        TeilenAct(
          title: 'Dritter Akt',
          note: 'Wer zerteilt, hat die Augen verbunden',
          foods: ['Toast', 'Wasser', 'Paprika'],
        ),
      ],
    ),
    MarioKartOlympiadeDiscipline(),
    GeoguessrOlympiadeDiscipline(
      stages: [
        GeoStage(
          title: 'Weltkarte · Bewegen',
          details: '2 Minuten pro Runde, Team-Durchschnitt',
        ),
        GeoStage(
          title: 'Weltkarte · No-Move',
          details: 'No-Move (Ehrensache), 2 Minuten pro Runde, bester Tipp',
        ),
        GeoStage(
          title: 'Deutschland · Bewegen',
          details: '30 Sekunden pro Runde, Team-Durchschnitt',
        ),
      ],
    ),
    RubiksOlympiadeDiscipline(),
    BasketballOlympiadeDiscipline(),
    CodenamesOlympiadeDiscipline(),
    BouleOlympiadeDiscipline(),
    BierpongOlympiadeDiscipline(),
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
);
