import 'package:flutter/material.dart';
import 'package:game_counter/olympiade/core/olympiade_discipline.dart';
import 'package:game_counter/olympiade/core/olympiade_models.dart';
import 'basketball_models.dart';
import 'basketball_service.dart';
import 'basketball_score_screen.dart';

/// Basketball Zerfetzung: BO3, pro Runde wird die Gewinner-WG eingetragen
class BasketballOlympiadeDiscipline extends OlympiadeDiscipline {
  const BasketballOlympiadeDiscipline();

  @override
  String get key => 'basketball';
  @override
  String get name => 'Basketball Zerfetzung';
  @override
  IconData get icon => Icons.sports_basketball;
  @override
  Color get color => Colors.deepOrangeAccent;
  @override
  OlympiadeDisciplineKind get kind => OlympiadeDisciplineKind.teams;

  @override
  List<OlympiadeSetting> get settings => const [
        OlympiadeSetting(
          key: 'winsNeeded',
          label: 'Siege zum Sieg',
          defaultValue: 2, // BO3
          presets: [1, 2, 3],
        ),
      ];

  @override
  Stream<Object?> watchGame(String gameId, OlympiadeGamesRef gamesRef) =>
      BasketballService(gamesRef: gamesRef).getGameStream(gameId);

  @override
  Future<String> startGame(OlympiadeStartRequest request) async {
    final game = await BasketballService(gamesRef: request.gamesRef).createGame(
      createdBy: request.createdBy,
      teams: List.generate(
        2,
        (i) => BasketballTeam(name: request.wgNames[i], playerUids: request.uids[i], playerNames: request.names[i]),
      ),
      winsNeeded: request.setting('winsNeeded', 2),
    );
    return game.id!;
  }

  @override
  Widget? scoreScreen(Object game, OlympiadeGamesRef gamesRef) => game is BasketballGame
      ? BasketballScoreScreen(game: game, service: BasketballService(gamesRef: gamesRef))
      : null;

  @override
  int? winnerFromGame(Object game, OlympiadeGame olympiade) => game is BasketballGame
      ? olympiadeTargetWinner(winnerIndex: game.winnerIndex, status: game.status, scores: game.wins)
      : null;

  @override
  String gameDetail(Object game, OlympiadeGame olympiade) =>
      game is BasketballGame ? 'Siege ${game.wins.join(' : ')}' : '';
}
