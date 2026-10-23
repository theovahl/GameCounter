import 'package:flutter/material.dart';
import 'package:game_counter/olympiade/core/olympiade_discipline.dart';
import 'package:game_counter/olympiade/core/olympiade_models.dart';
import 'halbieren_models.dart';
import 'halbieren_service.dart';
import 'halbieren_score_screen.dart';

// Ein Akt beim Großen Teilen: mehrere Lebensmittel mit einer gemeinsamen Erschwernis
class TeilenAct {
  final String title; // "Erster Akt"
  final String? note; // z.B. "Nur schwache Hand"
  final List<String> foods;

  const TeilenAct({required this.title, this.note, required this.foods});
}

/// Das Große Teilen: pro Lebensmittel trägt jede WG ihre Abweichung in Prozent ein,
/// die kleinere Gesamtabweichung gewinnt.
class TeilenOlympiadeDiscipline extends OlympiadeDiscipline {
  final List<TeilenAct> acts;
  final int secondsPerFood;

  const TeilenOlympiadeDiscipline({required this.acts, this.secondsPerFood = 180});

  @override
  String get key => 'halbieren'; // Schlüssel aus der ersten Version, bleibt für gespeicherte Daten
  @override
  String get name => 'Das Große Teilen';
  @override
  IconData get icon => Icons.content_cut;
  @override
  Color get color => Colors.orangeAccent;
  @override
  OlympiadeDisciplineKind get kind => OlympiadeDisciplineKind.teams;

  /// Alle Lebensmittel in der Reihenfolge der Akte
  List<TeilenFood> get foods => [
        for (int a = 0; a < acts.length; a++)
          for (final food in acts[a].foods)
            TeilenFood(act: a, actTitle: acts[a].title, actNote: acts[a].note, name: food),
      ];

  @override
  Stream<Object?> watchGame(String gameId, OlympiadeGamesRef gamesRef) =>
      HalbierenService(gamesRef: gamesRef).getGameStream(gameId);

  @override
  Future<String> startGame(OlympiadeStartRequest request) async {
    final game = await HalbierenService(gamesRef: request.gamesRef).createGame(
      createdBy: request.createdBy,
      teams: List.generate(
        2,
        (i) => HalbierenTeam(name: request.wgNames[i], playerUids: request.uids[i], playerNames: request.names[i]),
      ),
      foods: foods,
      secondsPerFood: secondsPerFood,
    );
    return game.id!;
  }

  @override
  Widget? scoreScreen(Object game, OlympiadeGamesRef gamesRef) => game is HalbierenGame
      ? HalbierenScoreScreen(game: game, service: HalbierenService(gamesRef: gamesRef))
      : null;

  // Kleinere Gesamtabweichung gewinnt, daher negiert vergleichen
  @override
  int? winnerFromGame(Object game, OlympiadeGame olympiade) {
    if (game is! HalbierenGame) return null;
    return olympiadeTargetWinner(
      winnerIndex: game.winnerIndex,
      status: game.status,
      scores: game.totals.map((t) => -t).toList(),
    );
  }

  @override
  String gameDetail(Object game, OlympiadeGame olympiade) {
    if (game is! HalbierenGame) return '';
    return 'Abweichung ${game.totals.map(formatTeilenPercent).join(' : ')} • '
        '${game.doneCount}/${game.foods.length} Lebensmittel';
  }
}
