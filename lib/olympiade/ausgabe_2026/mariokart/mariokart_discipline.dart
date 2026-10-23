import 'package:flutter/material.dart';
import 'package:game_counter/olympiade/core/olympiade_discipline.dart';
import 'package:game_counter/olympiade/core/olympiade_models.dart';
import 'mariokart_data.dart';
import 'mariokart_models.dart';
import 'mariokart_service.dart';
import 'mariokart_score_screen.dart';

/// Mario Kart in der WG Olympiade: frei gewählte Strecken, alle fahren einzeln,
/// es gewinnt die WG mit den meisten Durchschnittspunkten pro Fahrer.
class MarioKartOlympiadeDiscipline extends OlympiadeDiscipline {
  const MarioKartOlympiadeDiscipline();

  @override
  String get key => 'mariokart';
  @override
  String get name => 'Mario Kart';
  @override
  IconData get icon => Icons.sports_motorsports;
  @override
  Color get color => Colors.redAccent;
  @override
  OlympiadeDisciplineKind get kind => OlympiadeDisciplineKind.drivers;

  @override
  List<OlympiadeTrack> get selectableTracks => [
        for (final cup in MarioKartData.allCups)
          for (final track in cup.tracks)
            (name: track, group: cup.name, main: cup.category == 'Hauptspiel'),
      ];

  @override
  Stream<Object?> watchGame(String gameId, OlympiadeGamesRef gamesRef) =>
      MarioKartService(gamesRef: gamesRef).getGameStream(gameId);

  @override
  Future<String> startGame(OlympiadeStartRequest request) async {
    // Eigene Streckenauswahl statt eines festen Cups
    final cup = MarioKartCup(
      id: MarioKartData.customCupId,
      name: 'WG Olympiade',
      category: 'WG Olympiade',
      tracks: request.tracks,
    );
    // Keine echte Mario-Kart-Gruppe anlegen: das Spiel gehört nur zur Olympiade
    final group = MarioKartGroup(
      id: 'olympiade-${request.olympiade.id}',
      name: 'WG Olympiade: ${request.wgNames.join(' vs. ')}',
      createdBy: request.createdBy,
      playerUids: [...request.uids[0], ...request.uids[1]],
      playerNames: [...request.names[0], ...request.names[1]],
      createdAt: DateTime.now(),
    );
    final game = await MarioKartService(gamesRef: request.gamesRef)
        .createGame(group: group, cup: cup, createdBy: request.createdBy);
    return game.id!;
  }

  @override
  Widget? scoreScreen(Object game, OlympiadeGamesRef gamesRef) => game is MarioKartGame
      ? MarioKartScoreScreen(game: game, service: MarioKartService(gamesRef: gamesRef))
      : null;

  // Erst nach Spielende entschieden
  @override
  int? winnerFromGame(Object game, OlympiadeGame olympiade) {
    if (game is! MarioKartGame || game.status != 'finished') return null;
    return olympiadeLeader(averages(game, olympiade));
  }

  @override
  String gameDetail(Object game, OlympiadeGame olympiade) {
    if (game is! MarioKartGame) return '';
    final a = averages(game, olympiade);
    String fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    return 'Ø ${fmt(a[0])} : ${fmt(a[1])} Punkte • ${game.races.length} Rennen';
  }

  /// Durchschnittspunkte pro Fahrer je WG (so sind auch unterschiedlich große WGs fair)
  static List<double> averages(MarioKartGame game, OlympiadeGame olympiade) {
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
}
