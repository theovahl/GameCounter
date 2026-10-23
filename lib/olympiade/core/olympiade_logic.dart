import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'olympiade_models.dart';
import 'olympiade_discipline.dart';

// Ausgabenunabhängige Logik der WG Olympiade. Alles Disziplin-Spezifische erledigt die
// Disziplin der jeweiligen Ausgabe (siehe OlympiadeDiscipline).

// Farben der beiden WGs in der Olympiade
const List<Color> olympiadeWgColors = [Colors.pinkAccent, Colors.tealAccent];

/// Collection, in der die Spiele einer Disziplin dieser Olympiade liegen.
/// Neue Olympiaden speichern ihre Spiele getrennt von den normalen Modi unter
/// `olympiade_games/<id>/<key>_games`. Ältere Olympiaden nutzen noch die normalen
/// Collections der Modi (null = Standard-Collection des Service).
OlympiadeGamesRef olympiadeGamesRef(OlympiadeGame olympiade, String key) {
  if (!olympiade.separateGames || olympiade.id == null) return null;
  return FirebaseFirestore.instance
      .collection('olympiade_games')
      .doc(olympiade.id)
      .collection('${key}_games');
}

// --- Laden, Anzeigen & Starten ---

/// Live-Stream des verknüpften Spiels einer Disziplin (null = gelöscht oder unbekannt)
Stream<Object?> watchOlympiadeDisciplineGame(String key, String gameId, OlympiadeGame olympiade) {
  return olympiade.edition
      .discipline(key)
      .watchGame(gameId, olympiadeGamesRef(olympiade, key));
}

/// Lädt das verknüpfte Spiel einer Disziplin einmalig (null = gelöscht oder unbekannt)
Future<Object?> loadOlympiadeDisciplineGame(String key, String gameId, OlympiadeGame olympiade) {
  return watchOlympiadeDisciplineGame(key, gameId, olympiade).first;
}

/// Spielbildschirm zu einem Spiel einer Disziplin
Widget? olympiadeScoreScreenFor(OlympiadeGame olympiade, String key, Object game) {
  return olympiade.edition.discipline(key).scoreScreen(game, olympiadeGamesRef(olympiade, key));
}

/// Sieger-WG eines Spiels: 0, 1, olympiadeDraw oder null (läuft noch)
int? olympiadeWinnerFromGame(OlympiadeGame olympiade, String key, Object game) {
  return olympiade.edition.discipline(key).winnerFromGame(game, olympiade);
}

OlympiadeStartRequest _startRequest({
  required String key,
  required String createdBy,
  required OlympiadeGame olympiade,
  required List<List<String>> uids,
  required List<List<String>> names,
  Map<String, int> settings = const {},
  List<String> tracks = const [],
}) {
  return OlympiadeStartRequest(
    createdBy: createdBy,
    olympiade: olympiade,
    gamesRef: olympiadeGamesRef(olympiade, key),
    uids: uids,
    names: names,
    settings: settings,
    tracks: tracks,
  );
}

/// Legt das Spiel einer Disziplin an. Die beiden WGs werden zu den beiden Teams
/// (bzw. Spielern). Gibt die ID des neuen Spiels zurück.
Future<String> startOlympiadeDisciplineGame({
  required String key,
  required String createdBy,
  required OlympiadeGame olympiade,
  required List<List<String>> uids, // Teilnehmer pro WG
  required List<List<String>> names,
  required Map<String, int> settings,
  List<String> tracks = const [],
}) {
  return olympiade.edition.discipline(key).startGame(_startRequest(
        key: key,
        createdBy: createdBy,
        olympiade: olympiade,
        uids: uids,
        names: names,
        settings: settings,
        tracks: tracks,
      ));
}

/// Speichert ein direkt eingetragenes Ergebnis (z.B. Bierpong). Gibt die ID des Spiels zurück.
Future<String> saveOlympiadeInstantResult({
  required String key,
  required OlympiadeGame olympiade,
  required String createdBy,
  required List<List<String>> uids,
  required List<List<String>> names,
  required int winnerWg,
}) {
  return olympiade.edition.discipline(key).saveInstantResult(
        _startRequest(key: key, createdBy: createdBy, olympiade: olympiade, uids: uids, names: names),
        winnerWg,
      );
}

// --- Stand einer Disziplin ---

/// Summiert Legs/Siege aller Spiele einer Mehrfach-Disziplin pro WG.
/// [games] gehört Index für Index zu [gameIds]; null = gelöscht, fällt heraus.
OlympiadeResult olympiadeMultiGameResultFrom({
  required OlympiadeDiscipline discipline,
  required List<String> gameIds,
  required List<Object?> games,
  int? winnerWg,
}) {
  final tally = [0, 0];
  final keptIds = <String>[];
  bool lastGameActive = false;

  for (int i = 0; i < gameIds.length && i < games.length; i++) {
    final game = games[i];
    final gameTally = game != null ? discipline.gameTally(game) : null;
    if (gameTally == null) continue;
    tally[0] += gameTally[0];
    tally[1] += gameTally[1];
    lastGameActive = discipline.isGameActive(game!);
    keptIds.add(gameIds[i]);
  }

  return OlympiadeResult(
    gameIds: keptIds,
    tally: tally,
    lastGameActive: lastGameActive,
    winnerWg: winnerWg,
  );
}

/// Lädt alle Spiele einer Mehrfach-Disziplin und berechnet deren aktuellen Stand
Future<OlympiadeResult> olympiadeMultiGameResult(
  String key,
  OlympiadeResult current,
  OlympiadeGame olympiade,
) async {
  final games = await Future.wait(
    current.gameIds.map((id) => loadOlympiadeDisciplineGame(key, id, olympiade)),
  );
  return olympiadeMultiGameResultFrom(
    discipline: olympiade.edition.discipline(key),
    gameIds: current.gameIds,
    games: games,
    winnerWg: current.winnerWg,
  );
}

/// Live-Stand einer Disziplin aus den gerade geladenen Spielen, ohne dass die App
/// synchronisiert haben muss. [games] gehört Index für Index zu stored.gameIds.
OlympiadeResult olympiadeLiveResult({
  required String key,
  required OlympiadeResult stored,
  required List<Object?> games,
  required OlympiadeGame olympiade,
}) {
  // Manuell festgelegt oder noch gar nicht gestartet
  if (stored.gameIds.isEmpty) return stored;

  final discipline = olympiade.edition.discipline(key);
  if (discipline.multiGame) {
    // Mehrfach-Disziplinen gelten erst nach "Beenden" in der App als entschieden
    return olympiadeMultiGameResultFrom(
      discipline: discipline,
      gameIds: stored.gameIds,
      games: games,
      winnerWg: stored.winnerWg,
    );
  }

  final game = games.isNotEmpty ? games.last : null;
  if (game == null) return stored;
  return OlympiadeResult(
    gameIds: stored.gameIds,
    winnerWg: discipline.winnerFromGame(game, olympiade),
  );
}

/// Kurze Zusammenfassung des Spielstands einer Disziplin, z.B. "Siege 2 : 1"
/// oder "Legs 5 : 3 • 4/9 Matches". Leer, wenn noch nichts gespielt wurde.
String olympiadeResultDetail({
  required String key,
  required OlympiadeResult result,
  required List<Object?> games,
  required OlympiadeGame olympiade,
}) {
  final discipline = olympiade.edition.discipline(key);
  if (discipline.multiGame) {
    if (result.gameIds.isEmpty) return '';
    final count = result.gameIds.length;
    final total = olympiadeRoundRobinTotal(olympiade, key);
    return '${discipline.tallyLabel} ${result.tally.join(' : ')} • '
        '${total != null ? '$count/$total Matches' : '$count ${count == 1 ? "Spiel" : "Spiele"}'}';
  }

  final game = games.isNotEmpty ? games.last : null;
  return game != null ? discipline.gameDetail(game, olympiade) : '';
}

// --- Spielplan "jeder gegen jeden" (z.B. Dart, Bierpong) ---

/// Alle Duelle jeder gegen jeden, laut Disziplin ggf. mehrfach (Hin- und Rückrunde).
/// Leer, wenn die Disziplin keinen Spielplan hat.
List<OlympiadePairing> olympiadeRoundRobinPairings(OlympiadeGame olympiade, String key) {
  final rounds = olympiade.edition.discipline(key).roundRobinRounds;
  return [
    for (int r = 0; r < rounds; r++)
      for (final a in olympiade.wgs[0].playerUids)
        for (final b in olympiade.wgs[1].playerUids) (a: a, b: b),
  ];
}

int? olympiadeRoundRobinTotal(OlympiadeGame olympiade, String key) {
  final total = olympiadeRoundRobinPairings(olympiade, key).length;
  return total > 0 ? total : null;
}

/// Bereits gespielte Duelle aus den geladenen Spielen
List<OlympiadePairing> olympiadePlayedPairings(OlympiadeGame olympiade, String key, List<Object?> games) {
  final discipline = olympiade.edition.discipline(key);
  return [
    for (final game in games)
      if (game != null) ?discipline.duelPairing(game),
  ];
}

/// Noch offene Duelle: jedes gespielte Duell streicht ein Vorkommen aus dem Spielplan
List<OlympiadePairing> olympiadeOpenPairings(
  List<OlympiadePairing> all,
  List<OlympiadePairing> played,
) {
  final open = List<OlympiadePairing>.from(all);
  for (final p in played) {
    open.remove(p);
  }
  return open;
}
