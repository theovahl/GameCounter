import 'package:flutter/material.dart';
import 'package:game_counter/olympiade/core/olympiade_discipline.dart';
import 'package:game_counter/olympiade/core/olympiade_models.dart';
import 'codenames_models.dart';
import 'codenames_service.dart';
import 'codenames_score_screen.dart';

/// Codenames: BO5
class CodenamesOlympiadeDiscipline extends OlympiadeDiscipline {
  const CodenamesOlympiadeDiscipline();

  @override
  String get key => 'codenames';
  @override
  String get name => 'Codenames';
  @override
  IconData get icon => Icons.grid_view;
  @override
  Color get color => Colors.deepPurpleAccent;
  @override
  OlympiadeDisciplineKind get kind => OlympiadeDisciplineKind.teams;

  @override
  List<OlympiadeSetting> get settings => const [
        OlympiadeSetting(
          key: 'winsNeeded',
          label: 'Siege zum Sieg',
          defaultValue: 3, // BO5
          presets: [1, 2, 3],
        ),
      ];

  @override
  Stream<Object?> watchGame(String gameId, OlympiadeGamesRef gamesRef) =>
      CodenamesService(gamesRef: gamesRef).getGameStream(gameId);

  @override
  Future<String> startGame(OlympiadeStartRequest request) async {
    final game = await CodenamesService(gamesRef: request.gamesRef).createGame(
      createdBy: request.createdBy,
      teams: List.generate(
        2,
        (i) => CodenamesTeam(name: request.wgNames[i], playerUids: request.uids[i], playerNames: request.names[i]),
      ),
      winsNeeded: request.setting('winsNeeded', 3),
    );
    return game.id!;
  }

  @override
  Widget? scoreScreen(Object game, OlympiadeGamesRef gamesRef) => game is CodenamesGame
      ? CodenamesScoreScreen(game: game, service: CodenamesService(gamesRef: gamesRef))
      : null;

  @override
  int? winnerFromGame(Object game, OlympiadeGame olympiade) => game is CodenamesGame
      ? olympiadeTargetWinner(winnerIndex: game.winnerIndex, status: game.status, scores: game.wins)
      : null;

  @override
  String gameDetail(Object game, OlympiadeGame olympiade) =>
      game is CodenamesGame ? 'Siege ${game.wins.join(' : ')}' : '';
}
