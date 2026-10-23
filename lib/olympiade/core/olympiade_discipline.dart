import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'olympiade_models.dart';

/// Collection, in der die Spiele einer Disziplin liegen (null = Standard-Collection des Modus)
typedef OlympiadeGamesRef = CollectionReference<Map<String, dynamic>>?;

/// Ein Duell im Spielplan "jeder gegen jeden": a aus WG 0, b aus WG 1
typedef OlympiadePairing = ({String a, String b});

/// Eine auswählbare Strecke (Mario Kart). [main] = gehört zum Hauptspiel.
typedef OlympiadeTrack = ({String name, String group, bool main});

enum OlympiadeDisciplineKind {
  teams, // Alle ausgewählten Mitglieder einer WG bilden ein Team
  duel, // Je ein Spieler pro WG
  drivers, // Alle fahren einzeln, gewertet wird pro WG
}

// Eine einstellbare Zahl beim Starten einer Disziplin (z.B. Legs zum Sieg)
class OlympiadeSetting {
  final String key;
  final String label;
  final int defaultValue;
  final List<int> presets;
  final int min;
  final int max;

  const OlympiadeSetting({
    required this.key,
    required this.label,
    required this.defaultValue,
    required this.presets,
    this.min = 1,
    this.max = 21,
  });
}

/// Alles, was eine Disziplin zum Anlegen eines Spiels braucht
class OlympiadeStartRequest {
  final String createdBy;
  final OlympiadeGame olympiade;
  final OlympiadeGamesRef gamesRef;
  final List<List<String>> uids; // Teilnehmer pro WG
  final List<List<String>> names;
  final Map<String, int> settings;
  final List<String> tracks; // Mario Kart: gewählte Strecken

  const OlympiadeStartRequest({
    required this.createdBy,
    required this.olympiade,
    required this.gamesRef,
    required this.uids,
    required this.names,
    this.settings = const {},
    this.tracks = const [],
  });

  List<String> get wgNames => olympiade.wgs.map((w) => w.name).toList();

  int setting(String key, int fallback) => settings[key] ?? fallback;
}

/// Eine Disziplin der WG Olympiade. Jede Ausgabe (z.B. lib/olympiade/ausgabe_2026/)
/// bringt ihre eigenen Disziplinen mit: Name, Icon, Einstellungen und wie das Spiel
/// angelegt, angezeigt und gewertet wird. Der Kern der Olympiade kennt nur diese Schnittstelle.
abstract class OlympiadeDiscipline {
  const OlympiadeDiscipline();

  /// Schlüssel in Firestore (Ergebnisse & Collection `<key>_games`) – nie ändern!
  String get key;
  String get name;
  IconData get icon;
  Color get color;
  OlympiadeDisciplineKind get kind;

  List<OlympiadeSetting> get settings => const [];

  /// Mehrere Spiele pro Disziplin; gezählt werden die [tallyLabel] pro WG,
  /// bis die Disziplin in der Übersicht beendet wird (Dart, Bierpong)
  bool get multiGame => false;
  String get tallyLabel => '';

  /// Spielplan jeder gegen jeden: wie oft jede Paarung gespielt wird (0 = kein Spielplan)
  int get roundRobinRounds => 0;

  /// Ergebnis wird direkt im Startdialog eingetragen, kein Spielbildschirm (Bierpong)
  bool get instantResult => false;

  /// Strecken zur Auswahl im Startdialog (Mario Kart), sonst leer
  List<OlympiadeTrack> get selectableTracks => const [];

  /// Live-Stream eines Spiels dieser Disziplin (null = gelöscht)
  Stream<Object?> watchGame(String gameId, OlympiadeGamesRef gamesRef);

  /// Legt ein neues Spiel an und gibt dessen ID zurück
  Future<String> startGame(OlympiadeStartRequest request) {
    throw UnsupportedError('$name hat keinen Spielbildschirm');
  }

  /// Speichert ein direkt eingetragenes Ergebnis (nur bei [instantResult])
  Future<String> saveInstantResult(OlympiadeStartRequest request, int winnerWg) {
    throw UnsupportedError('$name trägt Ergebnisse nicht direkt ein');
  }

  /// Spielbildschirm zu einem Spiel dieser Disziplin
  Widget? scoreScreen(Object game, OlympiadeGamesRef gamesRef) => null;

  /// Sieger-WG eines einzelnen Spiels: 0, 1, olympiadeDraw oder null (läuft noch)
  int? winnerFromGame(Object game, OlympiadeGame olympiade) => null;

  /// Mehrfach-Disziplinen: Beitrag eines Spiels zum Stand pro WG (z.B. Legs)
  List<int>? gameTally(Object game) => null;

  /// Mehrfach-Disziplinen: läuft dieses Spiel noch?
  bool isGameActive(Object game) => false;

  /// Duelle: wer hat in diesem Spiel gegeneinander gespielt?
  OlympiadePairing? duelPairing(Object game) => null;

  /// Kurzer Spielstand eines einzelnen Spiels, z.B. "Siege 2 : 1"
  String gameDetail(Object game, OlympiadeGame olympiade) => '';

  /// Zusatzzeile für die Zuschauer-Seite bei einem laufenden Spiel, z.B. "Theo vs. Max"
  String? liveMatchup(Object game) => null;
}

/// Platzhalter für Disziplinen, die eine Ausgabe nicht (mehr) kennt
class UnknownOlympiadeDiscipline extends OlympiadeDiscipline {
  @override
  final String key;

  const UnknownOlympiadeDiscipline(this.key);

  @override
  String get name => key;
  @override
  IconData get icon => Icons.help_outline;
  @override
  Color get color => Colors.grey;
  @override
  OlympiadeDisciplineKind get kind => OlympiadeDisciplineKind.teams;

  @override
  Stream<Object?> watchGame(String gameId, OlympiadeGamesRef gamesRef) => Stream.value(null);
}

// --- Hilfsfunktionen für die Wertung ---

/// Index der führenden Seite oder olympiadeDraw bei Gleichstand
int olympiadeLeader(List<num> scores) {
  if (scores[0] > scores[1]) return 0;
  if (scores[1] > scores[0]) return 1;
  return olympiadeDraw;
}

/// Gewinner eines Spiels mit Siegziel. Wurde vorzeitig beendet, gewinnt wer führt.
int? olympiadeTargetWinner({
  required int? winnerIndex,
  required String status,
  required List<num> scores,
}) {
  if (winnerIndex != null) return winnerIndex;
  if (status != 'finished') return null;
  return olympiadeLeader(scores);
}
