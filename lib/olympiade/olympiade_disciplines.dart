import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_counter/mariokart/mariokart_data.dart';
import 'package:game_counter/mariokart/mariokart_models.dart';
import 'package:game_counter/mariokart/mariokart_service.dart';
import 'package:game_counter/mariokart/mariokart_score_screen.dart';
import 'package:game_counter/boule/boule_models.dart';
import 'package:game_counter/boule/boule_service.dart';
import 'package:game_counter/boule/boule_score_screen.dart';
import 'package:game_counter/darts/darts_models.dart';
import 'package:game_counter/darts/darts_service.dart';
import 'package:game_counter/darts/darts_score_screen.dart';
import 'package:game_counter/codenames/codenames_models.dart';
import 'package:game_counter/codenames/codenames_service.dart';
import 'package:game_counter/codenames/codenames_score_screen.dart';
import 'package:game_counter/halbieren/halbieren_models.dart';
import 'package:game_counter/halbieren/halbieren_service.dart';
import 'package:game_counter/halbieren/halbieren_score_screen.dart';
import 'package:game_counter/bierpong/bierpong_models.dart';
import 'package:game_counter/bierpong/bierpong_service.dart';
import 'package:game_counter/basketball/basketball_models.dart';
import 'package:game_counter/basketball/basketball_service.dart';
import 'package:game_counter/basketball/basketball_score_screen.dart';
import 'package:game_counter/geoguessr/geoguessr_models.dart';
import 'package:game_counter/geoguessr/geoguessr_service.dart';
import 'package:game_counter/geoguessr/geoguessr_score_screen.dart';
import 'package:game_counter/rubiks/rubiks_models.dart';
import 'package:game_counter/rubiks/rubiks_service.dart';
import 'package:game_counter/rubiks/rubiks_score_screen.dart';
import 'olympiade_models.dart';
import 'olympiade_editions.dart';

/// Collection, in der die Spiele einer Disziplin dieser Olympiade liegen.
/// Neue Olympiaden speichern ihre Spiele getrennt von den normalen Modi unter
/// `olympiade_games/<id>/<modus>_games`. Ältere Olympiaden nutzen noch die normalen
/// Collections der Modi (null = Standard-Collection des Service).
CollectionReference<Map<String, dynamic>>? olympiadeGamesRef(OlympiadeGame olympiade, String key) {
  if (!olympiade.separateGames || olympiade.id == null) return null;
  return FirebaseFirestore.instance
      .collection('olympiade_games')
      .doc(olympiade.id)
      .collection('${key}_games');
}

// Farben der beiden WGs in der Olympiade
const List<Color> olympiadeWgColors = [Colors.pinkAccent, Colors.tealAccent];

enum OlympiadeDisciplineKind {
  teams, // Alle ausgewählten Mitglieder einer WG bilden ein Team
  duel, // Je ein Spieler pro WG
  drivers, // Mario Kart: alle fahren einzeln, gewertet wird pro WG
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

class OlympiadeDiscipline {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  final OlympiadeDisciplineKind kind;
  final List<OlympiadeSetting> settings;
  final bool instantResult; // Bierpong: Gewinner wird direkt eingetragen, kein Spielbildschirm
  // Mehrere Spiele pro Disziplin; gezählt werden die [tallyLabel] pro WG, bis in der Übersicht beendet wird
  final bool multiGame;
  final String tallyLabel;

  const OlympiadeDiscipline({
    required this.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.kind,
    this.settings = const [],
    this.instantResult = false,
    this.multiGame = false,
    this.tallyLabel = '',
  });
}

const OlympiadeSetting _winsNeeded = OlympiadeSetting(
  key: 'winsNeeded',
  label: 'Siege zum Sieg',
  defaultValue: 2,
  presets: [1, 2, 3],
);

const Map<String, OlympiadeDiscipline> olympiadeDisciplineInfo = {
  'mariokart': OlympiadeDiscipline(
    key: 'mariokart',
    name: 'Mario Kart',
    icon: Icons.sports_motorsports,
    color: Colors.redAccent,
    kind: OlympiadeDisciplineKind.drivers,
  ),
  'boule': OlympiadeDiscipline(
    key: 'boule',
    name: 'Boule',
    icon: Icons.scatter_plot,
    color: Colors.lightBlueAccent,
    kind: OlympiadeDisciplineKind.teams,
    settings: [
      OlympiadeSetting(
        key: 'pointsPerSet',
        label: 'Punkte pro Satz',
        defaultValue: 13,
        presets: [7, 11, 13],
        max: 99,
      ),
      OlympiadeSetting(
        key: 'setsToWin',
        label: 'Gewinnsätze',
        defaultValue: 1,
        presets: [1, 2, 3],
        max: 9,
      ),
    ],
  ),
  'darts': OlympiadeDiscipline(
    key: 'darts',
    name: 'Dart',
    icon: Icons.gps_fixed,
    color: Colors.greenAccent,
    kind: OlympiadeDisciplineKind.duel,
    multiGame: true,
    tallyLabel: 'Legs',
    settings: [
      OlympiadeSetting(
        key: 'legsToWin',
        label: 'Legs zum Sieg',
        defaultValue: 3,
        presets: [1, 2, 3, 5],
      ),
    ],
  ),
  'codenames': OlympiadeDiscipline(
    key: 'codenames',
    name: 'Codenames',
    icon: Icons.grid_view,
    color: Colors.deepPurpleAccent,
    kind: OlympiadeDisciplineKind.teams,
    settings: [_winsNeeded],
  ),
  'halbieren': OlympiadeDiscipline(
    key: 'halbieren',
    name: 'Das Große Teilen',
    icon: Icons.content_cut,
    color: Colors.orangeAccent,
    kind: OlympiadeDisciplineKind.teams,
    // Ablauf (Akte & Lebensmittel) kommt aus der Ausgabe
  ),
  'bierpong': OlympiadeDiscipline(
    key: 'bierpong',
    name: 'Bierpong',
    icon: Icons.sports_bar,
    color: Colors.yellowAccent,
    kind: OlympiadeDisciplineKind.duel,
    instantResult: true,
    multiGame: true,
    tallyLabel: 'Siege',
  ),
  'basketball': OlympiadeDiscipline(
    key: 'basketball',
    name: 'Basketball Zerfetzung',
    icon: Icons.sports_basketball,
    color: Colors.deepOrangeAccent,
    kind: OlympiadeDisciplineKind.teams,
    settings: [_winsNeeded],
  ),
  'geoguessr': OlympiadeDiscipline(
    key: 'geoguessr',
    name: 'GeoGuessr',
    icon: Icons.public,
    color: Colors.lightGreenAccent,
    kind: OlympiadeDisciplineKind.teams,
    // Stufen kommen aus der Ausgabe
  ),
  'rubiks': OlympiadeDiscipline(
    key: 'rubiks',
    name: "Rubik's Cube Action",
    icon: Icons.view_in_ar,
    color: Colors.cyanAccent,
    kind: OlympiadeDisciplineKind.teams,
    settings: [_winsNeeded],
  ),
};

OlympiadeDiscipline olympiadeDiscipline(String key) =>
    olympiadeDisciplineInfo[key] ??
    OlympiadeDiscipline(key: key, name: key, icon: Icons.help_outline, color: Colors.grey, kind: OlympiadeDisciplineKind.teams);

// --- Ergebnisberechnung ---

// Index der führenden Seite oder olympiadeDraw bei Gleichstand
int olympiadeLeader(List<num> scores) {
  if (scores[0] > scores[1]) return 0;
  if (scores[1] > scores[0]) return 1;
  return olympiadeDraw;
}

// Gewinner eines Spiels mit Siegziel. Wurde vorzeitig beendet, gewinnt wer führt.
int? olympiadeTargetWinner({
  required int? winnerIndex,
  required String status,
  required List<num> scores,
}) {
  if (winnerIndex != null) return winnerIndex;
  if (status != 'finished') return null;
  return olympiadeLeader(scores);
}

int? olympiadeBouleWinner(BouleGame game) {
  if (game.winnerTeam != null) return game.winnerTeam;
  if (game.status != 'finished') return null;
  final bySets = olympiadeLeader(game.setsWon);
  if (bySets != olympiadeDraw) return bySets;
  return olympiadeLeader(game.currentSet.scores);
}

// Mario Kart: Sieger ist die WG mit den meisten Durchschnittspunkten pro Fahrer
// (so sind auch unterschiedlich große WGs fair). Erst nach Spielende entschieden.
int? olympiadeMarioKartWinner(MarioKartGame game, OlympiadeGame olympiade) {
  if (game.status != 'finished') return null;
  return olympiadeLeader(olympiadeMarioKartAverages(game, olympiade));
}

int? olympiadeWinnerFromGame(Object game, OlympiadeGame olympiade) {
  return switch (game) {
    MarioKartGame g => olympiadeMarioKartWinner(g, olympiade),
    BouleGame g => olympiadeBouleWinner(g),
    DartsGame g => olympiadeTargetWinner(winnerIndex: g.winnerIndex, status: g.status, scores: g.legsWon),
    CodenamesGame g => olympiadeTargetWinner(winnerIndex: g.winnerIndex, status: g.status, scores: g.wins),
    // Kleinere Gesamtabweichung gewinnt, daher negiert vergleichen
    HalbierenGame g => olympiadeTargetWinner(
        winnerIndex: g.winnerIndex,
        status: g.status,
        scores: g.totals.map((t) => -t).toList(),
      ),
    BasketballGame g => olympiadeTargetWinner(winnerIndex: g.winnerIndex, status: g.status, scores: g.wins),
    GeoguessrGame g => olympiadeTargetWinner(winnerIndex: g.winnerIndex, status: g.status, scores: g.wins),
    RubiksGame g => olympiadeTargetWinner(winnerIndex: g.winnerIndex, status: g.status, scores: g.wins),
    _ => null,
  };
}

/// Summiert Legs (Dart) bzw. Siege (Bierpong) aller Spiele einer Mehrfach-Disziplin pro WG.
/// [games] gehört Index für Index zu [gameIds]; null = gelöscht, fällt heraus.
/// Spieler 0 ist immer der Vertreter von WG 0.
OlympiadeResult olympiadeMultiGameResultFrom({
  required List<String> gameIds,
  required List<Object?> games,
  int? winnerWg,
}) {
  final tally = [0, 0];
  final keptIds = <String>[];
  bool lastGameActive = false;

  for (int i = 0; i < gameIds.length && i < games.length; i++) {
    final game = games[i];
    if (game is DartsGame) {
      tally[0] += game.legsWon[0];
      tally[1] += game.legsWon[1];
      lastGameActive = game.status == 'active';
    } else if (game is BierpongGame) {
      tally[game.winnerIndex]++;
      lastGameActive = false;
    } else {
      continue;
    }
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

  if (olympiadeDiscipline(key).multiGame) {
    // Mehrfach-Disziplinen gelten erst nach "Beenden" in der App als entschieden
    return olympiadeMultiGameResultFrom(
      gameIds: stored.gameIds,
      games: games,
      winnerWg: stored.winnerWg,
    );
  }

  final game = games.isNotEmpty ? games.last : null;
  if (game == null) return stored;
  return OlympiadeResult(
    gameIds: stored.gameIds,
    winnerWg: olympiadeWinnerFromGame(game, olympiade),
  );
}

/// Durchschnittspunkte pro Fahrer je WG (Mario Kart)
List<double> olympiadeMarioKartAverages(MarioKartGame game, OlympiadeGame olympiade) {
  final totals = [0.0, 0.0];
  final drivers = [0, 0];
  final scores = game.calculatedTotalScores;
  for (final uid in game.playerUids) {
    final wg = olympiade.wgs.indexWhere((w) => w.playerUids.contains(uid));
    if (wg < 0) continue;
    totals[wg] += game.hasMultipliers
        ? (game.modifiedTotalScores[uid] ?? 0)
        : (scores[uid] ?? 0).toDouble();
    drivers[wg]++;
  }
  return [
    drivers[0] > 0 ? totals[0] / drivers[0] : 0,
    drivers[1] > 0 ? totals[1] / drivers[1] : 0,
  ];
}

/// Kurze Zusammenfassung des Spielstands einer Disziplin für die Zuschauer-Seite,
/// z.B. "Siege 2 : 1" oder "Satz 2 • 5 : 3". Leer, wenn noch nichts gespielt wurde.
String olympiadeResultDetail({
  required String key,
  required OlympiadeResult result,
  required List<Object?> games,
  required OlympiadeGame olympiade,
}) {
  final info = olympiadeDiscipline(key);
  if (info.multiGame) {
    if (result.gameIds.isEmpty) return '';
    final count = result.gameIds.length;
    final total = olympiadeRoundRobinTotal(olympiade, key);
    return '${info.tallyLabel} ${result.tally.join(' : ')} • '
        '${total != null ? '$count/$total Matches' : '$count ${count == 1 ? "Spiel" : "Spiele"}'}';
  }

  final game = games.isNotEmpty ? games.last : null;
  String avg(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
  return switch (game) {
    MarioKartGame g => () {
        final a = olympiadeMarioKartAverages(g, olympiade);
        return 'Ø ${avg(a[0])} : ${avg(a[1])} Punkte • ${g.races.length} Rennen';
      }(),
    BouleGame g => g.setsToWin > 1
        ? 'Sätze ${g.setsWon.join(' : ')}'
            '${g.winnerTeam == null ? ' • Satz ${g.currentSet.setNumber}: ${g.currentSet.scores.join(' : ')}' : ''}'
        : g.currentSet.scores.join(' : '),
    CodenamesGame g => 'Siege ${g.wins.join(' : ')}',
    HalbierenGame g => 'Abweichung ${g.totals.map(formatTeilenPercent).join(' : ')} • '
        '${g.doneCount}/${g.foods.length} Lebensmittel',
    BasketballGame g => 'Siege ${g.wins.join(' : ')}',
    GeoguessrGame g => 'Runden ${g.wins.join(' : ')}'
        '${g.currentStageIndex != null ? ' • Stufe ${g.currentStageIndex! + 1}/${g.stages.length}' : ''}',
    RubiksGame g => 'Siege ${g.wins.join(' : ')}',
    _ => '',
  };
}

// --- Ablauf aus der Ausgabe ---

/// Lebensmittel für "Das Große Teilen" in der Reihenfolge der Akte
List<TeilenFood> olympiadeTeilenFoods(OlympiadeEdition edition) {
  return [
    for (int a = 0; a < edition.teilenActs.length; a++)
      for (final food in edition.teilenActs[a].foods)
        TeilenFood(
          act: a,
          actTitle: edition.teilenActs[a].title,
          actNote: edition.teilenActs[a].note,
          name: food,
        ),
  ];
}

/// GeoGuessr-Stufen der Ausgabe
List<GeoguessrStage> olympiadeGeoguessrStages(OlympiadeEdition edition) {
  return edition.geoguessrStages
      .map((s) => GeoguessrStage(title: s.title, details: s.details, winsNeeded: s.winsNeeded))
      .toList();
}

// --- Spielplan "jeder gegen jeden" (Dart, Bierpong) ---

typedef OlympiadePairing = ({String a, String b}); // a aus WG 0, b aus WG 1

/// Alle Duelle jeder gegen jeden, laut Ausgabe ggf. mehrfach (Hin- und Rückrunde).
/// Leer, wenn die Disziplin keinen Spielplan hat.
List<OlympiadePairing> olympiadeRoundRobinPairings(OlympiadeGame olympiade, String key) {
  final rounds = olympiade.edition.roundRobin[key] ?? 0;
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

/// Bereits gespielte Duelle aus den geladenen Spielen (Spieler 0 = WG 0)
List<OlympiadePairing> olympiadePlayedPairings(List<Object?> games) {
  return [
    for (final game in games)
      if (game is DartsGame && game.playerUids.length == 2)
        (a: game.playerUids[0], b: game.playerUids[1])
      else if (game is BierpongGame && game.playerUids.length == 2)
        (a: game.playerUids[0], b: game.playerUids[1]),
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

// Alle Mario-Kart-Strecken (aus Hauptspiel und Booster-Streckenpass) mit ihrem Cup
List<({String track, String cup})> get olympiadeMarioKartTracks => [
      for (final cup in MarioKartData.allCups)
        for (final track in cup.tracks) (track: track, cup: cup.name),
    ];

// --- Laden & Öffnen der verknüpften Spiele ---

/// Live-Stream des verknüpften Spiels einer Disziplin (null = gelöscht oder unbekannt)
Stream<Object?> watchOlympiadeDisciplineGame(String key, String gameId, OlympiadeGame olympiade) {
  final ref = olympiadeGamesRef(olympiade, key);
  return switch (key) {
    'mariokart' => MarioKartService(gamesRef: ref).getGameStream(gameId),
    'boule' => BouleService(gamesRef: ref).getGameStream(gameId),
    'darts' => DartsService(gamesRef: ref).getGameStream(gameId),
    'codenames' => CodenamesService(gamesRef: ref).getGameStream(gameId),
    'halbieren' => HalbierenService(gamesRef: ref).getGameStream(gameId),
    'bierpong' => BierpongService(gamesRef: ref).getGameStream(gameId),
    'basketball' => BasketballService(gamesRef: ref).getGameStream(gameId),
    'geoguessr' => GeoguessrService(gamesRef: ref).getGameStream(gameId),
    'rubiks' => RubiksService(gamesRef: ref).getGameStream(gameId),
    _ => Stream.value(null),
  };
}

/// Lädt das verknüpfte Spiel einer Disziplin einmalig (null = gelöscht oder unbekannt)
Future<Object?> loadOlympiadeDisciplineGame(String key, String gameId, OlympiadeGame olympiade) {
  return watchOlympiadeDisciplineGame(key, gameId, olympiade).first;
}

Widget? olympiadeScoreScreenFor(Object game, OlympiadeGame olympiade) {
  CollectionReference<Map<String, dynamic>>? ref(String key) => olympiadeGamesRef(olympiade, key);
  return switch (game) {
    MarioKartGame g => MarioKartScoreScreen(game: g, service: MarioKartService(gamesRef: ref('mariokart'))),
    BouleGame g => BouleScoreScreen(game: g, service: BouleService(gamesRef: ref('boule'))),
    DartsGame g => DartsScoreScreen(game: g, service: DartsService(gamesRef: ref('darts'))),
    CodenamesGame g => CodenamesScoreScreen(game: g, service: CodenamesService(gamesRef: ref('codenames'))),
    HalbierenGame g => HalbierenScoreScreen(game: g, service: HalbierenService(gamesRef: ref('halbieren'))),
    BasketballGame g => BasketballScoreScreen(game: g, service: BasketballService(gamesRef: ref('basketball'))),
    GeoguessrGame g => GeoguessrScoreScreen(game: g, service: GeoguessrService(gamesRef: ref('geoguessr'))),
    RubiksGame g => RubiksScoreScreen(game: g, service: RubiksService(gamesRef: ref('rubiks'))),
    _ => null,
  };
}

// --- Starten einer Disziplin ---

/// Legt das Spiel im jeweiligen Modus an. Die beiden WGs werden zu den beiden Teams
/// (bzw. Spielern). Gibt die ID des neuen Spiels zurück.
Future<String?> startOlympiadeDisciplineGame({
  required String key,
  required String createdBy,
  required OlympiadeGame olympiade,
  required List<List<String>> uids, // Teilnehmer pro WG
  required List<List<String>> names,
  required Map<String, int> settings,
  List<String> tracks = const [],
}) async {
  final wgNames = olympiade.wgs.map((w) => w.name).toList();
  int setting(String k, int fallback) => settings[k] ?? fallback;
  final ref = olympiadeGamesRef(olympiade, key);

  switch (key) {
    case 'mariokart':
      // Eigene Streckenauswahl statt eines festen Cups
      final cup = MarioKartCup(
        id: MarioKartData.customCupId,
        name: 'WG Olympiade',
        category: 'WG Olympiade',
        tracks: tracks,
      );
      // Keine echte Mario-Kart-Gruppe anlegen: das Spiel gehört nur zur Olympiade
      final group = MarioKartGroup(
        id: 'olympiade-${olympiade.id}',
        name: 'WG Olympiade: ${wgNames.join(' vs. ')}',
        createdBy: createdBy,
        playerUids: [...uids[0], ...uids[1]],
        playerNames: [...names[0], ...names[1]],
        createdAt: DateTime.now(),
      );
      final game = await MarioKartService(gamesRef: ref).createGame(group: group, cup: cup, createdBy: createdBy);
      return game.id;

    case 'boule':
      final game = await BouleService(gamesRef: ref).createGame(
        createdBy: createdBy,
        teams: List.generate(
          2,
          (i) => BouleTeam(name: wgNames[i], playerUids: uids[i], playerNames: names[i]),
        ),
        pointsPerSet: setting('pointsPerSet', 13),
        setsToWin: setting('setsToWin', 1),
      );
      return game.id;

    case 'darts':
      final game = await DartsService(gamesRef: ref).createGame(
        createdBy: createdBy,
        playerUids: [uids[0].first, uids[1].first],
        playerNames: [names[0].first, names[1].first],
        legsToWin: setting('legsToWin', 3),
      );
      return game.id;

    case 'codenames':
      final game = await CodenamesService(gamesRef: ref).createGame(
        createdBy: createdBy,
        teams: List.generate(
          2,
          (i) => CodenamesTeam(name: wgNames[i], playerUids: uids[i], playerNames: names[i]),
        ),
        winsNeeded: setting('winsNeeded', 2),
      );
      return game.id;

    case 'halbieren':
      final game = await HalbierenService(gamesRef: ref).createGame(
        createdBy: createdBy,
        teams: List.generate(
          2,
          (i) => HalbierenTeam(name: wgNames[i], playerUids: uids[i], playerNames: names[i]),
        ),
        foods: olympiadeTeilenFoods(olympiade.edition),
        secondsPerFood: olympiade.edition.teilenSecondsPerFood,
      );
      return game.id;

    case 'basketball':
      final game = await BasketballService(gamesRef: ref).createGame(
        createdBy: createdBy,
        teams: List.generate(
          2,
          (i) => BasketballTeam(name: wgNames[i], playerUids: uids[i], playerNames: names[i]),
        ),
        winsNeeded: setting('winsNeeded', 2),
      );
      return game.id;

    case 'geoguessr':
      final game = await GeoguessrService(gamesRef: ref).createGame(
        createdBy: createdBy,
        teams: List.generate(
          2,
          (i) => GeoguessrTeam(name: wgNames[i], playerUids: uids[i], playerNames: names[i]),
        ),
        stages: olympiadeGeoguessrStages(olympiade.edition),
      );
      return game.id;

    case 'rubiks':
      final game = await RubiksService(gamesRef: ref).createGame(
        createdBy: createdBy,
        teams: List.generate(
          2,
          (i) => RubiksTeam(name: wgNames[i], playerUids: uids[i], playerNames: names[i]),
        ),
        winsNeeded: setting('winsNeeded', 2),
      );
      return game.id;
  }
  return null;
}

/// Bierpong hat keinen Spielbildschirm: das Ergebnis wird direkt gespeichert.
/// Gibt die ID des Spiels zurück.
Future<String> saveOlympiadeBierpongResult({
  required OlympiadeGame olympiade,
  required String createdBy,
  required List<List<String>> uids,
  required List<List<String>> names,
  required int winnerWg,
}) async {
  return BierpongService(gamesRef: olympiadeGamesRef(olympiade, 'bierpong')).saveGame(
    createdBy: createdBy,
    playerUids: [uids[0].first, uids[1].first],
    playerNames: [names[0].first, names[1].first],
    winnerIndex: winnerWg,
  );
}
