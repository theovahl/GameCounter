import 'package:flutter/material.dart';
import 'package:game_counter/olympiade/core/olympiade_discipline.dart';
import 'bierpong_models.dart';
import 'bierpong_service.dart';

/// Bierpong: jeder gegen jeden mit Hin- und Rückrunde, gezählt werden die Siege pro WG.
/// Kein Spielbildschirm, der Gewinner wird direkt im Startdialog eingetragen.
class BierpongOlympiadeDiscipline extends OlympiadeDiscipline {
  const BierpongOlympiadeDiscipline();

  @override
  String get key => 'bierpong';
  @override
  String get name => 'Bierpong';
  @override
  IconData get icon => Icons.sports_bar;
  @override
  Color get color => Colors.yellowAccent;
  @override
  OlympiadeDisciplineKind get kind => OlympiadeDisciplineKind.duel;

  @override
  bool get instantResult => true;
  @override
  bool get multiGame => true;
  @override
  String get tallyLabel => 'Siege';
  @override
  int get roundRobinRounds => 2; // Hin- und Rückrunde

  @override
  Stream<Object?> watchGame(String gameId, OlympiadeGamesRef gamesRef) =>
      BierpongService(gamesRef: gamesRef).getGameStream(gameId);

  @override
  Future<String> saveInstantResult(OlympiadeStartRequest request, int winnerWg) {
    return BierpongService(gamesRef: request.gamesRef).saveGame(
      createdBy: request.createdBy,
      playerUids: [request.uids[0].first, request.uids[1].first],
      playerNames: [request.names[0].first, request.names[1].first],
      winnerIndex: winnerWg,
    );
  }

  // Spieler 0 vertritt immer WG 0
  @override
  List<int>? gameTally(Object game) {
    if (game is! BierpongGame) return null;
    return [game.winnerIndex == 0 ? 1 : 0, game.winnerIndex == 1 ? 1 : 0];
  }

  @override
  OlympiadePairing? duelPairing(Object game) => game is BierpongGame && game.playerUids.length == 2
      ? (a: game.playerUids[0], b: game.playerUids[1])
      : null;
}
