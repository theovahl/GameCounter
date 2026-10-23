import 'package:flutter/material.dart';
import 'package:game_counter/olympiade/core/olympiade_discipline.dart';
import 'package:game_counter/olympiade/core/olympiade_models.dart';
import 'boule_models.dart';
import 'boule_service.dart';
import 'boule_score_screen.dart';

/// Boule: BO3, jeweils bis 15
class BouleOlympiadeDiscipline extends OlympiadeDiscipline {
  const BouleOlympiadeDiscipline();

  @override
  String get key => 'boule';
  @override
  String get name => 'Boule';
  @override
  IconData get icon => Icons.scatter_plot;
  @override
  Color get color => Colors.lightBlueAccent;
  @override
  OlympiadeDisciplineKind get kind => OlympiadeDisciplineKind.teams;

  @override
  List<OlympiadeSetting> get settings => const [
        OlympiadeSetting(
          key: 'pointsPerSet',
          label: 'Punkte pro Satz',
          defaultValue: 15,
          presets: [11, 13, 15],
          max: 99,
        ),
        OlympiadeSetting(
          key: 'setsToWin',
          label: 'Gewinnsätze',
          defaultValue: 2, // BO3
          presets: [1, 2, 3],
          max: 9,
        ),
      ];

  @override
  Stream<Object?> watchGame(String gameId, OlympiadeGamesRef gamesRef) =>
      BouleService(gamesRef: gamesRef).getGameStream(gameId);

  @override
  Future<String> startGame(OlympiadeStartRequest request) async {
    final game = await BouleService(gamesRef: request.gamesRef).createGame(
      createdBy: request.createdBy,
      teams: List.generate(
        2,
        (i) => BouleTeam(name: request.wgNames[i], playerUids: request.uids[i], playerNames: request.names[i]),
      ),
      pointsPerSet: request.setting('pointsPerSet', 15),
      setsToWin: request.setting('setsToWin', 2),
    );
    return game.id!;
  }

  @override
  Widget? scoreScreen(Object game, OlympiadeGamesRef gamesRef) => game is BouleGame
      ? BouleScoreScreen(game: game, service: BouleService(gamesRef: gamesRef))
      : null;

  // Vorzeitig beendet: erst die Sätze, dann die Punkte im laufenden Satz vergleichen
  @override
  int? winnerFromGame(Object game, OlympiadeGame olympiade) {
    if (game is! BouleGame) return null;
    if (game.winnerTeam != null) return game.winnerTeam;
    if (game.status != 'finished') return null;
    final bySets = olympiadeLeader(game.setsWon);
    if (bySets != olympiadeDraw) return bySets;
    return olympiadeLeader(game.currentSet.scores);
  }

  @override
  String gameDetail(Object game, OlympiadeGame olympiade) {
    if (game is! BouleGame) return '';
    if (game.setsToWin <= 1) return game.currentSet.scores.join(' : ');
    return 'Sätze ${game.setsWon.join(' : ')}'
        '${game.winnerTeam == null ? ' • Satz ${game.currentSet.setNumber}: ${game.currentSet.scores.join(' : ')}' : ''}';
  }
}
