import 'package:flutter/material.dart';
import 'package:game_counter/olympiade/core/olympiade_discipline.dart';
import 'package:game_counter/olympiade/core/olympiade_models.dart';
import 'rubiks_models.dart';
import 'rubiks_service.dart';
import 'rubiks_score_screen.dart';

/// Rubik's Cube Action: beide WGs lösen gleichzeitig, wer zuerst fertig ist, gewinnt
class RubiksOlympiadeDiscipline extends OlympiadeDiscipline {
  const RubiksOlympiadeDiscipline();

  @override
  String get key => 'rubiks';
  @override
  String get name => "Rubik's Cube Action";
  @override
  IconData get icon => Icons.view_in_ar;
  @override
  Color get color => Colors.cyanAccent;
  @override
  OlympiadeDisciplineKind get kind => OlympiadeDisciplineKind.teams;

  @override
  List<OlympiadeSetting> get settings => const [
        OlympiadeSetting(
          key: 'winsNeeded',
          label: 'Siege zum Sieg',
          defaultValue: 1, // ein Durchgang, wer zuerst fertig ist
          presets: [1, 2, 3],
        ),
      ];

  @override
  Stream<Object?> watchGame(String gameId, OlympiadeGamesRef gamesRef) =>
      RubiksService(gamesRef: gamesRef).getGameStream(gameId);

  @override
  Future<String> startGame(OlympiadeStartRequest request) async {
    final game = await RubiksService(gamesRef: request.gamesRef).createGame(
      createdBy: request.createdBy,
      teams: List.generate(
        2,
        (i) => RubiksTeam(name: request.wgNames[i], playerUids: request.uids[i], playerNames: request.names[i]),
      ),
      winsNeeded: request.setting('winsNeeded', 1),
    );
    return game.id!;
  }

  @override
  Widget? scoreScreen(Object game, OlympiadeGamesRef gamesRef) => game is RubiksGame
      ? RubiksScoreScreen(game: game, service: RubiksService(gamesRef: gamesRef))
      : null;

  @override
  int? winnerFromGame(Object game, OlympiadeGame olympiade) => game is RubiksGame
      ? olympiadeTargetWinner(winnerIndex: game.winnerIndex, status: game.status, scores: game.wins)
      : null;

  @override
  String gameDetail(Object game, OlympiadeGame olympiade) =>
      game is RubiksGame ? 'Siege ${game.wins.join(' : ')}' : '';
}
