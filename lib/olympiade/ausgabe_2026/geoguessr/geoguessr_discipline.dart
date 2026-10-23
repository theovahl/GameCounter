import 'package:flutter/material.dart';
import 'package:game_counter/olympiade/core/olympiade_discipline.dart';
import 'package:game_counter/olympiade/core/olympiade_models.dart';
import 'geoguessr_models.dart';
import 'geoguessr_service.dart';
import 'geoguessr_score_screen.dart';

// Eine Stufe bei GeoGuessr (jeweils Best of)
class GeoStage {
  final String title; // "Weltkarte · Bewegen"
  final String details; // "2 Minuten pro Runde, Team-Durchschnitt"
  final int winsNeeded; // 2 = BO3

  const GeoStage({required this.title, required this.details, this.winsNeeded = 2});
}

/// GeoGuessr: mehrere Stufen als Best of, gezählt wird die Gesamtzahl gewonnener Runden
class GeoguessrOlympiadeDiscipline extends OlympiadeDiscipline {
  final List<GeoStage> stages;

  const GeoguessrOlympiadeDiscipline({required this.stages});

  @override
  String get key => 'geoguessr';
  @override
  String get name => 'GeoGuessr';
  @override
  IconData get icon => Icons.public;
  @override
  Color get color => Colors.lightGreenAccent;
  @override
  OlympiadeDisciplineKind get kind => OlympiadeDisciplineKind.teams;

  @override
  Stream<Object?> watchGame(String gameId, OlympiadeGamesRef gamesRef) =>
      GeoguessrService(gamesRef: gamesRef).getGameStream(gameId);

  @override
  Future<String> startGame(OlympiadeStartRequest request) async {
    final game = await GeoguessrService(gamesRef: request.gamesRef).createGame(
      createdBy: request.createdBy,
      teams: List.generate(
        2,
        (i) => GeoguessrTeam(name: request.wgNames[i], playerUids: request.uids[i], playerNames: request.names[i]),
      ),
      stages: stages
          .map((s) => GeoguessrStage(title: s.title, details: s.details, winsNeeded: s.winsNeeded))
          .toList(),
    );
    return game.id!;
  }

  @override
  Widget? scoreScreen(Object game, OlympiadeGamesRef gamesRef) => game is GeoguessrGame
      ? GeoguessrScoreScreen(game: game, service: GeoguessrService(gamesRef: gamesRef))
      : null;

  @override
  int? winnerFromGame(Object game, OlympiadeGame olympiade) => game is GeoguessrGame
      ? olympiadeTargetWinner(winnerIndex: game.winnerIndex, status: game.status, scores: game.wins)
      : null;

  @override
  String gameDetail(Object game, OlympiadeGame olympiade) {
    if (game is! GeoguessrGame) return '';
    final stage = game.currentStageIndex;
    return 'Runden ${game.wins.join(' : ')}'
        '${stage != null ? ' • Stufe ${stage + 1}/${game.stages.length}' : ''}';
  }
}
