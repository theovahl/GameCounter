import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/olympiade/ausgabe_2026/bierpong/bierpong_models.dart';
import 'package:game_counter/olympiade/ausgabe_2026/boule/boule_discipline.dart';
import 'package:game_counter/olympiade/ausgabe_2026/boule/boule_models.dart';
import 'package:game_counter/olympiade/ausgabe_2026/codenames/codenames_models.dart';
import 'package:game_counter/olympiade/ausgabe_2026/darts/darts_models.dart';
import 'package:game_counter/olympiade/ausgabe_2026/mariokart/mariokart_data.dart';
import 'package:game_counter/olympiade/ausgabe_2026/mariokart/mariokart_discipline.dart';
import 'package:game_counter/olympiade/ausgabe_2026/mariokart/mariokart_models.dart';
import 'package:game_counter/olympiade/core/olympiade_discipline.dart';
import 'package:game_counter/olympiade/core/olympiade_logic.dart';
import 'package:game_counter/olympiade/core/olympiade_models.dart';

OlympiadeGame _olympiade({Map<String, OlympiadeResult>? results, List<String>? disciplines}) {
  return OlympiadeGame(
    id: 'o1',
    createdBy: 'u1',
    date: DateTime(2026, 10, 22),
    memberUids: ['u1', 'u2', 'u3', 'u4', 'u5'],
    wgs: [
      OlympiadeWg(name: 'Unsere WG', playerUids: ['u1', 'u2'], playerNames: ['Theo', 'Anna']),
      OlympiadeWg(name: 'Gegner-WG', playerUids: ['u3', 'u4', 'u5'], playerNames: ['Max', 'Ben', 'Lea']),
    ],
    disciplines: disciplines ?? ['boule', 'darts', 'codenames'],
    results: results,
  );
}

void main() {
  group('Olympiade standings', () {
    test('counts wins and draws as points', () {
      final o = _olympiade(results: {
        'boule': const OlympiadeResult(gameIds: ['g1'], winnerWg: 0),
        'darts': const OlympiadeResult(winnerWg: olympiadeDraw),
      });
      expect(o.points, [1.5, 0.5]);
      expect(o.doneCount, 2);
      expect(o.remainingCount, 1);
      expect(o.allDone, isFalse);
    });

    test('result states: open, running, done', () {
      final o = _olympiade(results: {
        'boule': const OlympiadeResult(gameIds: ['g1']),
        'darts': const OlympiadeResult(winnerWg: 1),
      });
      expect(o.resultFor('boule').isRunning, isTrue);
      expect(o.resultFor('darts').isDone, isTrue);
      expect(o.resultFor('codenames').isOpen, isTrue);
    });

    test('detects an unbeatable lead', () {
      final o = _olympiade(results: {
        'boule': const OlympiadeResult(winnerWg: 1),
        'darts': const OlympiadeResult(winnerWg: 1),
      });
      expect(o.decidedWinner, 1);

      final open = _olympiade(results: {'boule': const OlympiadeResult(winnerWg: 1)});
      expect(open.decidedWinner, isNull);
    });

    test('serializes and restores results', () {
      final o = _olympiade(results: {
        'boule': const OlympiadeResult(gameIds: ['g1'], winnerWg: 0),
        'darts': const OlympiadeResult(gameIds: ['g2']),
      });
      final restored = OlympiadeGame.fromMap(o.toMap(), id: 'o1');
      expect(restored.wgs[1].playerNames, ['Max', 'Ben', 'Lea']);
      expect(restored.disciplines, ['boule', 'darts', 'codenames']);
      expect(restored.resultFor('boule').winnerWg, 0);
      expect(restored.resultFor('darts').gameId, 'g2');
      expect(restored.resultFor('darts').isRunning, isTrue);
    });

    test('multi-game results keep games, tally and running state', () {
      const result = OlympiadeResult(
        gameIds: ['d1', 'd2'],
        tally: [5, 3],
        lastGameActive: true,
      );
      expect(result.isRunning, isTrue);
      expect(result.gameId, 'd2');

      final restored = OlympiadeResult.fromMap(result.toMap());
      expect(restored.gameIds, ['d1', 'd2']);
      expect(restored.tally, [5, 3]);
      expect(restored.lastGameActive, isTrue);
      expect(restored.sameAs(result), isTrue);
      expect(restored.sameAs(const OlympiadeResult(gameIds: ['d1', 'd2'], tally: [5, 4])), isFalse);
    });

    test('remembers whether games are stored separately from the normal modes', () {
      final newer = OlympiadeGame.fromMap({..._olympiade().toMap(), 'separateGames': true}, id: 'o1');
      expect(newer.separateGames, isTrue);
      expect(newer.copyWithResult('boule', const OlympiadeResult(winnerWg: 0)).separateGames, isTrue);

      // Ältere Olympiaden ohne das Feld nutzen weiter die normalen Collections
      final older = OlympiadeGame.fromMap(_olympiade().toMap()..remove('separateGames'), id: 'o2');
      expect(older.separateGames, isFalse);
      expect(olympiadeGamesRef(older, 'boule'), isNull);
    });

    test('reads older results with a single gameId', () {
      final restored = OlympiadeResult.fromMap({'gameId': 'g1', 'winnerWg': null});
      expect(restored.gameIds, ['g1']);
      expect(restored.isRunning, isTrue);
    });

    test('dart and bierpong are multi-game disciplines', () {
      final edition = _olympiade().edition;
      expect(edition.discipline('darts').multiGame, isTrue);
      expect(edition.discipline('bierpong').multiGame, isTrue);
      expect(edition.discipline('codenames').multiGame, isFalse);
      expect(edition.discipline('gibt-es-nicht'), isA<UnknownOlympiadeDiscipline>());
    });

    test('formats points', () {
      expect(formatOlympiadePoints(3), '3');
      expect(formatOlympiadePoints(2.5), '2,5');
    });
  });

  group('Olympiade discipline results', () {
    test('a decided game gives the win to that WG', () {
      final codenames = CodenamesGame(
        createdBy: 'u1',
        date: DateTime(2026, 10, 22),
        memberUids: ['u1', 'u3'],
        teams: [
          CodenamesTeam(name: 'Unsere WG', playerUids: ['u1'], playerNames: ['Theo']),
          CodenamesTeam(name: 'Gegner-WG', playerUids: ['u3'], playerNames: ['Max']),
        ],
        winsNeeded: 2,
        rounds: [CodenamesRound(winnerIndex: 1), CodenamesRound(winnerIndex: 1)],
      );
      expect(olympiadeWinnerFromGame(_olympiade(), 'codenames', codenames), 1);
    });

    test('dart is not decided per game but by the legs of all matches', () {
      final darts = DartsGame(
        createdBy: 'u1',
        date: DateTime(2026, 10, 22),
        playerUids: ['u1', 'u3'],
        playerNames: ['Theo', 'Max'],
        legsToWin: 2,
        legs: [DartsLeg(winnerIndex: 1), DartsLeg(winnerIndex: 1)],
      );
      final discipline = _olympiade().edition.discipline('darts');
      expect(discipline.winnerFromGame(darts, _olympiade()), isNull);
      expect(discipline.gameTally(darts), [0, 2]);
    });

    test('a running game has no result yet', () {
      expect(olympiadeTargetWinner(winnerIndex: null, status: 'active', scores: [1, 0]), isNull);
    });

    test('an early finished game goes to the leader, or is a draw', () {
      expect(olympiadeTargetWinner(winnerIndex: null, status: 'finished', scores: [2, 1]), 0);
      expect(olympiadeTargetWinner(winnerIndex: null, status: 'finished', scores: [1, 1]), olympiadeDraw);
    });

    test('boule falls back to sets, then current set points', () {
      final boule = BouleGame(
        createdBy: 'u1',
        date: DateTime(2026, 10, 22),
        memberUids: ['u1', 'u3'],
        teams: [
          BouleTeam(name: 'Unsere WG', playerUids: ['u1'], playerNames: ['Theo']),
          BouleTeam(name: 'Gegner-WG', playerUids: ['u3'], playerNames: ['Max']),
        ],
        pointsPerSet: 13,
        ends: [BouleEnd(teamIndex: 1, points: 5), BouleEnd(teamIndex: 0, points: 2)],
        status: 'finished',
      );
      expect(const BouleOlympiadeDiscipline().winnerFromGame(boule, _olympiade()), 1);
    });

    test('mario kart compares average points per driver of each WG', () {
      final game = MarioKartGame(
        groupId: 'g',
        groupName: 'WG Olympiade',
        cups: [],
        createdBy: 'u1',
        date: DateTime(2026, 10, 22),
        playerUids: ['u1', 'u2', 'u3', 'u4', 'u5'],
        playerNames: ['Theo', 'Anna', 'Max', 'Ben', 'Lea'],
        races: [
          MarioKartRace(
            cupIndex: 0,
            trackIndex: 0,
            trackName: 'Test',
            placements: {'u1': 1, 'u2': 2, 'u3': 3, 'u4': 4, 'u5': 5},
            // WG 1: (15 + 12) / 2 = 13,5  vs.  WG 2: (10 + 9 + 8) / 3 = 9
            points: {'u1': 15, 'u2': 12, 'u3': 10, 'u4': 9, 'u5': 8},
          ),
        ],
        status: 'finished',
      );
      expect(const MarioKartOlympiadeDiscipline().winnerFromGame(game, _olympiade()), 0);
    });

    test('mario kart with own track selection finishes after all chosen tracks', () {
      final game = MarioKartGame(
        groupId: 'g',
        groupName: 'WG Olympiade',
        cups: [
          const MarioKartCupInfo(cupId: MarioKartData.customCupId, cupName: 'WG Olympiade', tracks: ['A', 'B']),
        ],
        createdBy: 'u1',
        date: DateTime(2026, 10, 22),
        playerUids: ['u1', 'u3'],
        playerNames: ['Theo', 'Max'],
        races: [
          MarioKartRace(trackIndex: 0, trackName: 'A', placements: {'u1': 1, 'u3': 2}, points: {'u1': 15, 'u3': 12}),
          MarioKartRace(trackIndex: 1, trackName: 'B', placements: {'u1': 2, 'u3': 1}, points: {'u1': 12, 'u3': 15}),
        ],
      );
      expect(game.trackCountForCup(0), 2);
      expect(game.isCupFinished(0), isTrue);
    });

    test('all mario kart tracks are selectable, 48 of them from the main game', () {
      final tracks = const MarioKartOlympiadeDiscipline().selectableTracks;
      expect(tracks.length, 96);
      expect(tracks.where((t) => t.main).length, 48);
    });
  });

  group('Olympiade live view', () {
    DartsGame darts(List<int> legWinners, {int legsToWin = 3}) => DartsGame(
          createdBy: 'u1',
          date: DateTime(2026, 10, 22),
          playerUids: ['u1', 'u3'],
          playerNames: ['Theo', 'Max'],
          legsToWin: legsToWin,
          legs: legWinners.map((w) => DartsLeg(winnerIndex: w)).toList(),
        );

    BierpongGame bierpong(int winner) => BierpongGame(
          createdBy: 'u1',
          date: DateTime(2026, 10, 22),
          playerUids: ['u1', 'u3'],
          playerNames: ['Theo', 'Max'],
          winnerIndex: winner,
        );

    test('sums legs of all dart games and drops deleted ones', () {
      final result = olympiadeMultiGameResultFrom(
        discipline: _olympiade().edition.discipline('darts'),
        gameIds: ['d1', 'd2', 'd3'],
        games: [darts([0, 0, 0]), null, darts([1, 0])],
      );
      expect(result.gameIds, ['d1', 'd3']);
      expect(result.tally, [4, 1]);
      expect(result.lastGameActive, isTrue);
    });

    test('counts bierpong wins per WG', () {
      final result = olympiadeMultiGameResultFrom(
        discipline: _olympiade().edition.discipline('bierpong'),
        gameIds: ['b1', 'b2', 'b3'],
        games: [bierpong(1), bierpong(0), bierpong(1)],
      );
      expect(result.tally, [1, 2]);
      expect(result.lastGameActive, isFalse);
    });

    test('a finished game counts live before the app has synced', () {
      final codenames = CodenamesGame(
        createdBy: 'u1',
        date: DateTime(2026, 10, 22),
        memberUids: ['u1', 'u3'],
        teams: [
          CodenamesTeam(name: 'Unsere WG', playerUids: ['u1'], playerNames: ['Theo']),
          CodenamesTeam(name: 'Gegner-WG', playerUids: ['u3'], playerNames: ['Max']),
        ],
        winsNeeded: 2,
        rounds: [CodenamesRound(winnerIndex: 1), CodenamesRound(winnerIndex: 1)],
      );
      final live = olympiadeLiveResult(
        key: 'codenames',
        stored: const OlympiadeResult(gameIds: ['c1']),
        games: [codenames],
        olympiade: _olympiade(),
      );
      expect(live.winnerWg, 1);
      expect(
        olympiadeResultDetail(key: 'codenames', result: live, games: [codenames], olympiade: _olympiade()),
        'Siege 0 : 2',
      );
    });

    test('dart stays running until it is finished in the app', () {
      final live = olympiadeLiveResult(
        key: 'darts',
        stored: const OlympiadeResult(gameIds: ['d1']),
        games: [darts([0, 0, 0])],
        olympiade: _olympiade(),
      );
      expect(live.isRunning, isTrue);
      expect(live.tally, [3, 0]);
      expect(
        olympiadeResultDetail(key: 'darts', result: live, games: const [], olympiade: _olympiade()),
        'Legs 3 : 0 • 1/6 Matches', // 2 × 3 Spieler, jeder gegen jeden
      );
    });

    test('manually set results are kept', () {
      const stored = OlympiadeResult(winnerWg: 0);
      final live = olympiadeLiveResult(key: 'boule', stored: stored, games: const [], olympiade: _olympiade());
      expect(live.winnerWg, 0);
    });

    test('builds the live link', () {
      expect(olympiadeLiveUrl('abc123'), 'https://game-counter-tv.web.app/?o=abc123');
    });
  });

  group('Olympiade round robin', () {
    // _olympiade(): WG 0 = u1, u2  •  WG 1 = u3, u4, u5
    test('dart: everyone plays everyone once', () {
      final o = _olympiade();
      final all = olympiadeRoundRobinPairings(o, 'darts');
      expect(all.length, 6);
      expect(olympiadeRoundRobinTotal(o, 'darts'), 6);
      expect(all.first, (a: 'u1', b: 'u3'));
    });

    test('bierpong: home and away round doubles the matches', () {
      expect(olympiadeRoundRobinTotal(_olympiade(), 'bierpong'), 12);
    });

    test('disciplines without a schedule have none', () {
      expect(olympiadeRoundRobinPairings(_olympiade(), 'codenames'), isEmpty);
      expect(olympiadeRoundRobinTotal(_olympiade(), 'codenames'), isNull);
    });

    test('played games remove one occurrence of their pairing', () {
      final o = _olympiade();
      final played = olympiadePlayedPairings(o, 'bierpong', [
        BierpongGame(
          createdBy: 'u1',
          date: DateTime(2026, 10, 23),
          playerUids: ['u1', 'u3'],
          playerNames: ['Theo', 'Max'],
          winnerIndex: 0,
        ),
        null, // gelöschtes Spiel
      ]);
      final open = olympiadeOpenPairings(olympiadeRoundRobinPairings(o, 'bierpong'), played);
      expect(open.length, 11);
      // Rückspiel Theo gegen Max ist noch offen
      expect(open.where((p) => p == (a: 'u1', b: 'u3')).length, 1);
    });
  });
}
