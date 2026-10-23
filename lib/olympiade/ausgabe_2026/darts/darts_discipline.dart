import 'package:flutter/material.dart';
import 'package:game_counter/olympiade/core/olympiade_discipline.dart';
import 'darts_models.dart';
import 'darts_service.dart';
import 'darts_score_screen.dart';

/// Dart: BO5, jeder gegen jeden, am Ende werden die Legs aller Matches gezählt
class DartsOlympiadeDiscipline extends OlympiadeDiscipline {
  const DartsOlympiadeDiscipline();

  @override
  String get key => 'darts';
  @override
  String get name => 'Dart';
  @override
  IconData get icon => Icons.gps_fixed;
  @override
  Color get color => Colors.greenAccent;
  @override
  OlympiadeDisciplineKind get kind => OlympiadeDisciplineKind.duel;

  @override
  bool get multiGame => true;
  @override
  String get tallyLabel => 'Legs';
  @override
  int get roundRobinRounds => 1; // jeder gegen jeden

  @override
  List<OlympiadeSetting> get settings => const [
        OlympiadeSetting(
          key: 'legsToWin',
          label: 'Legs zum Sieg',
          defaultValue: 3, // BO5
          presets: [1, 2, 3, 5],
        ),
      ];

  @override
  Stream<Object?> watchGame(String gameId, OlympiadeGamesRef gamesRef) =>
      DartsService(gamesRef: gamesRef).getGameStream(gameId);

  @override
  Future<String> startGame(OlympiadeStartRequest request) async {
    final game = await DartsService(gamesRef: request.gamesRef).createGame(
      createdBy: request.createdBy,
      playerUids: [request.uids[0].first, request.uids[1].first],
      playerNames: [request.names[0].first, request.names[1].first],
      legsToWin: request.setting('legsToWin', 3),
    );
    return game.id!;
  }

  @override
  Widget? scoreScreen(Object game, OlympiadeGamesRef gamesRef) => game is DartsGame
      ? DartsScoreScreen(game: game, service: DartsService(gamesRef: gamesRef))
      : null;

  // Spieler 0 vertritt immer WG 0
  @override
  List<int>? gameTally(Object game) => game is DartsGame ? game.legsWon : null;

  @override
  bool isGameActive(Object game) => game is DartsGame && game.status == 'active';

  @override
  OlympiadePairing? duelPairing(Object game) => game is DartsGame && game.playerUids.length == 2
      ? (a: game.playerUids[0], b: game.playerUids[1])
      : null;

  @override
  String? liveMatchup(Object game) => game is DartsGame && game.status == 'active'
      ? '${game.playerNames.join(' vs. ')} • Legs ${game.legsWon.join(' : ')}'
      : null;
}
