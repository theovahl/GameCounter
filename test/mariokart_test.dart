import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/mariokart/mariokart_data.dart';
import 'package:game_counter/mariokart/mariokart_models.dart';

void main() {
  group('Mario Kart Data & Points Tests', () {
    test('Official points distribution is correct', () {
      expect(MarioKartData.getPointsForPlacement(1), 15);
      expect(MarioKartData.getPointsForPlacement(2), 12);
      expect(MarioKartData.getPointsForPlacement(3), 10);
      expect(MarioKartData.getPointsForPlacement(4), 9);
      expect(MarioKartData.getPointsForPlacement(5), 8);
      expect(MarioKartData.getPointsForPlacement(6), 7);
      expect(MarioKartData.getPointsForPlacement(7), 6);
      expect(MarioKartData.getPointsForPlacement(8), 5);
      expect(MarioKartData.getPointsForPlacement(9), 4);
      expect(MarioKartData.getPointsForPlacement(10), 3);
      expect(MarioKartData.getPointsForPlacement(11), 2);
      expect(MarioKartData.getPointsForPlacement(12), 1);
      expect(MarioKartData.getPointsForPlacement(0), 0);
    });

    test('All 24 cups are present and each has exactly 4 tracks', () {
      expect(MarioKartData.allCups.length, 24);

      final baseCups = MarioKartData.allCups.where((c) => c.category == 'Hauptspiel');
      final boosterCups =
          MarioKartData.allCups.where((c) => c.category == 'Booster-Streckenpass');

      expect(baseCups.length, 12);
      expect(boosterCups.length, 12);

      for (var cup in MarioKartData.allCups) {
        expect(cup.tracks.length, 4, reason: '${cup.name} must have 4 tracks');
      }
    });
  });

  group('Mario Kart Models Tests', () {
    test('MarioKartGame calculates total scores across races correctly', () {
      final game = MarioKartGame(
        id: 'game1',
        groupId: 'group1',
        groupName: 'Freunde Runde',
        cupId: 'mushroom',
        cupName: 'Pilz-Cup',
        cupTracks: ['Map 1', 'Map 2', 'Map 3', 'Map 4'],
        createdBy: 'userA',
        date: DateTime.now(),
        playerUids: ['userA', 'userB', 'userC'],
        playerNames: ['Theo', 'Max', 'Anna'],
        races: [
          MarioKartRace(
            trackIndex: 0,
            trackName: 'Map 1',
            placements: {'userA': 1, 'userB': 2, 'userC': 3},
            points: {'userA': 15, 'userB': 12, 'userC': 10},
          ),
          MarioKartRace(
            trackIndex: 1,
            trackName: 'Map 2',
            placements: {'userA': 2, 'userB': 1, 'userC': 3},
            points: {'userA': 12, 'userB': 15, 'userC': 10},
          ),
        ],
      );

      final totals = game.calculatedTotalScores;
      expect(totals['userA'], 27); // 15 + 12
      expect(totals['userB'], 27); // 12 + 15
      expect(totals['userC'], 20); // 10 + 10

      // Leaderboard sorting
      final ranked = game.rankedPlayerUids;
      expect(ranked.contains('userA'), isTrue);
      expect(ranked.contains('userB'), isTrue);
      expect(ranked.last, 'userC');
    });

    test('MarioKartGroup equality and serialization', () {
      final group = MarioKartGroup(
        id: 'g1',
        name: 'Switch-Crew',
        createdBy: 'userA',
        playerUids: ['userA', 'userB', 'userC', 'userD', 'userE'],
        playerNames: ['Theo', 'Max', 'Anna', 'Ben', 'Clara'],
        createdAt: DateTime(2026, 9, 5),
      );

      final map = group.toMap();
      expect(map['name'], 'Switch-Crew');
      expect(map['playerUids'].length, 5);

      final restored = MarioKartGroup.fromMap(map, id: 'g1');
      expect(restored, equals(group));
      expect(restored.playerNames.length, 5);
    });

    test('MarioKartGame supports multiple consecutive cups in a match', () {
      const cup1 = MarioKartCupInfo(
        cupId: 'mushroom',
        cupName: 'Pilz-Cup',
        tracks: ['Track 1', 'Track 2', 'Track 3', 'Track 4'],
      );
      const cup2 = MarioKartCupInfo(
        cupId: 'star',
        cupName: 'Stern-Cup',
        tracks: ['Track 5', 'Track 6', 'Track 7', 'Track 8'],
      );

      final game = MarioKartGame(
        id: 'game_multi',
        groupId: 'group1',
        groupName: 'Freunde Runde',
        cups: [cup1, cup2],
        createdBy: 'userA',
        date: DateTime.now(),
        playerUids: ['userA', 'userB'],
        playerNames: ['Theo', 'Max'],
        races: [
          // Cup 0: 4 races
          MarioKartRace(
            cupIndex: 0,
            trackIndex: 0,
            trackName: 'Track 1',
            placements: {'userA': 1, 'userB': 2},
            points: {'userA': 15, 'userB': 12},
          ),
          MarioKartRace(
            cupIndex: 0,
            trackIndex: 1,
            trackName: 'Track 2',
            placements: {'userA': 1, 'userB': 2},
            points: {'userA': 15, 'userB': 12},
          ),
          MarioKartRace(
            cupIndex: 0,
            trackIndex: 2,
            trackName: 'Track 3',
            placements: {'userA': 1, 'userB': 2},
            points: {'userA': 15, 'userB': 12},
          ),
          MarioKartRace(
            cupIndex: 0,
            trackIndex: 3,
            trackName: 'Track 4',
            placements: {'userA': 1, 'userB': 2},
            points: {'userA': 15, 'userB': 12},
          ),
          // Cup 1: 1 race
          MarioKartRace(
            cupIndex: 1,
            trackIndex: 0,
            trackName: 'Track 5',
            placements: {'userA': 2, 'userB': 1},
            points: {'userA': 12, 'userB': 15},
          ),
        ],
      );

      expect(game.cups.length, 2);
      expect(game.activeCupIndex, 1);
      expect(game.activeCup.cupName, 'Stern-Cup');
      expect(game.isCupFinished(0), isTrue);
      expect(game.isCupFinished(1), isFalse);
      expect(game.isActiveCupFinished, isFalse);

      final totals = game.calculatedTotalScores;
      expect(totals['userA'], 72); // 15*4 + 12
      expect(totals['userB'], 63); // 12*4 + 15
    });

    test('MarioKartGroupStats calculates leaderboard, medals, averages and progression', () {
      final game1 = MarioKartGame(
        id: 'g1',
        groupId: 'group1',
        groupName: 'Switch-Crew',
        createdBy: 'u1',
        date: DateTime(2026, 9, 1),
        playerUids: ['u1', 'u2'],
        playerNames: ['Theo', 'Max'],
        status: 'finished',
        races: [
          MarioKartRace(
            trackIndex: 0,
            trackName: 'Track A',
            placements: {'u1': 1, 'u2': 2},
            points: {'u1': 15, 'u2': 12},
          ),
          MarioKartRace(
            trackIndex: 1,
            trackName: 'Track B',
            placements: {'u1': 2, 'u2': 1},
            points: {'u1': 12, 'u2': 15},
          ),
        ],
      );

      final game2 = MarioKartGame(
        id: 'g2',
        groupId: 'group1',
        groupName: 'Switch-Crew',
        createdBy: 'u1',
        date: DateTime(2026, 9, 2),
        playerUids: ['u1', 'u2'],
        playerNames: ['Theo', 'Max'],
        status: 'finished',
        races: [
          MarioKartRace(
            trackIndex: 0,
            trackName: 'Track C',
            placements: {'u1': 1, 'u2': 2},
            points: {'u1': 15, 'u2': 12},
          ),
        ],
      );

      final stats = MarioKartGroupStats(
        games: [game1, game2],
        playerUids: ['u1', 'u2'],
        playerNames: ['Theo', 'Max'],
      );

      expect(stats.totalMatches, 2);
      expect(stats.finishedMatches, 2);
      expect(stats.totalRaces, 3);

      final leaderboard = stats.leaderboard;
      expect(leaderboard.length, 2);

      // u1 (Theo): 15 + 12 + 15 = 42 pts. 2 wins, 1 second place. Avg: 42/3 = 14.0
      final theo = leaderboard.firstWhere((p) => p.uid == 'u1');
      expect(theo.name, 'Theo');
      expect(theo.totalPoints, 42);
      expect(theo.racesCount, 3);
      expect(theo.wins, 2);
      expect(theo.secondPlaces, 1);
      expect(theo.thirdPlaces, 0);
      expect(theo.avgPointsPerRace, closeTo(14.0, 0.01));
      expect(theo.winRatePercentage, closeTo(66.67, 0.1));

      // u2 (Max): 12 + 15 + 12 = 39 pts. 1 win, 2 second places. Avg: 39/3 = 13.0
      final max = leaderboard.firstWhere((p) => p.uid == 'u2');
      expect(max.name, 'Max');
      expect(max.totalPoints, 39);
      expect(max.racesCount, 3);
      expect(max.wins, 1);
      expect(max.secondPlaces, 2);
      expect(max.avgPointsPerRace, closeTo(13.0, 0.01));
      expect(max.winRatePercentage, closeTo(33.33, 0.1));

      // u1 is rank 1
      expect(leaderboard.first.uid, 'u1');

      // Check race progression: Start + 3 races = 4 points
      final racePoints = stats.raceProgression;
      expect(racePoints.length, 4);
      expect(racePoints[0].label, 'Start');
      expect(racePoints[0].cumulativePoints['u1'], 0);
      expect(racePoints[1].label, 'Track A');
      expect(racePoints[1].cumulativePoints['u1'], 15);
      expect(racePoints[2].label, 'Track B');
      expect(racePoints[2].cumulativePoints['u1'], 27);
      expect(racePoints[3].label, 'Track C');
      expect(racePoints[3].cumulativePoints['u1'], 42);

      // Check match progression: Start + 2 matches = 3 points
      final matchPoints = stats.matchProgression;
      expect(matchPoints.length, 3);
      expect(matchPoints[0].label, 'Start');
      expect(matchPoints[1].label, 'M1');
      expect(matchPoints[1].cumulativePoints['u1'], 27); // Game 1 total
      expect(matchPoints[2].label, 'M2');
      expect(matchPoints[2].cumulativePoints['u1'], 42); // Game 1 + Game 2
    });

    test('Multiplier logic and MarioKartGroupStats with useMultipliers', () {
      // 1. Multiplier progression
      expect(MarioKartData.getMultiplierForRank(1), 1.0);
      expect(MarioKartData.getMultiplierForRank(2), 1.1);
      expect(MarioKartData.getMultiplierForRank(3), 1.22);
      expect(MarioKartData.getMultiplierForRank(4), 1.36);
      expect(MarioKartData.getMultiplierForRank(5), 1.52);

      // 2. Initial state: No games finished yet -> everyone gets 1.0
      final initialStats = MarioKartGroupStats(
        games: [],
        playerUids: ['u1', 'u2', 'u3', 'u4'],
        playerNames: ['Theo', 'Max', 'Anna', 'Ben'],
        useMultipliers: true,
      );
      final initialMultipliers =
          initialStats.calculateMultipliersForMatch(['u1', 'u2', 'u3', 'u4']);
      expect(initialMultipliers['u1'], 1.0);
      expect(initialMultipliers['u2'], 1.0);
      expect(initialMultipliers['u3'], 1.0);
      expect(initialMultipliers['u4'], 1.0);

      // 3. Match 1 finishes: Theo 40, Max 30, Anna 20, Ben 10
      final game1 = MarioKartGame(
        id: 'game1',
        groupId: 'g1',
        groupName: 'Switch Crew',
        createdBy: 'u1',
        date: DateTime(2026, 9, 1),
        playerUids: ['u1', 'u2', 'u3', 'u4'],
        playerNames: ['Theo', 'Max', 'Anna', 'Ben'],
        status: 'finished',
        hasMultipliers: true,
        appliedMultipliers: {'u1': 1.0, 'u2': 1.0, 'u3': 1.0, 'u4': 1.0},
        modifiedTotalScores: {'u1': 40.0, 'u2': 30.0, 'u3': 20.0, 'u4': 10.0},
        races: [
          MarioKartRace(
            trackIndex: 0,
            trackName: 'Piste 1',
            placements: {'u1': 1, 'u2': 2, 'u3': 3, 'u4': 4},
            points: {'u1': 40, 'u2': 30, 'u3': 20, 'u4': 10},
          ),
        ],
      );

      final statsAfterGame1 = MarioKartGroupStats(
        games: [game1],
        playerUids: ['u1', 'u2', 'u3', 'u4'],
        playerNames: ['Theo', 'Max', 'Anna', 'Ben'],
        useMultipliers: true,
      );

      // Next match multipliers:
      // Theo is 1st -> 1.0
      // Max is 2nd -> 1.1
      // Anna is 3rd -> 1.22
      // Ben is 4th -> 1.36
      final nextMultipliers =
          statsAfterGame1.calculateMultipliersForMatch(['u1', 'u2', 'u3', 'u4']);
      expect(nextMultipliers['u1'], 1.0);
      expect(nextMultipliers['u2'], 1.1);
      expect(nextMultipliers['u3'], 1.22);
      expect(nextMultipliers['u4'], 1.36);

      // 4. Game 2 finishes with multipliers:
      // Raw: Theo 30, Max 30, Anna 30, Ben 30
      // Modified:
      // Theo: 30 * 1.0 = 30.0
      // Max: 30 * 1.1 = 33.0
      // Anna: 30 * 1.22 = 36.6
      // Ben: 30 * 1.36 = 40.8
      final game2 = MarioKartGame(
        id: 'game2',
        groupId: 'g1',
        groupName: 'Switch Crew',
        createdBy: 'u1',
        date: DateTime(2026, 9, 2),
        playerUids: ['u1', 'u2', 'u3', 'u4'],
        playerNames: ['Theo', 'Max', 'Anna', 'Ben'],
        status: 'finished',
        hasMultipliers: true,
        appliedMultipliers: nextMultipliers,
        modifiedTotalScores: {'u1': 30.0, 'u2': 33.0, 'u3': 36.6, 'u4': 40.8},
        races: [
          MarioKartRace(
            trackIndex: 0,
            trackName: 'Piste 2',
            placements: {'u1': 1, 'u2': 2, 'u3': 3, 'u4': 4},
            points: {'u1': 30, 'u2': 30, 'u3': 30, 'u4': 30},
          ),
        ],
      );

      // In Game 2: Ben won with modified points!
      expect(game2.rankedModifiedPlayerUids.first, 'u4');

      // Check stats across game 1 and game 2 with multipliers:
      final totalStatsWithMulti = MarioKartGroupStats(
        games: [game1, game2],
        playerUids: ['u1', 'u2', 'u3', 'u4'],
        playerNames: ['Theo', 'Max', 'Anna', 'Ben'],
        useMultipliers: true,
      );

      final multiLeaderboard = totalStatsWithMulti.leaderboard;
      // Theo total: 40.0 + 30.0 = 70.0
      // Max total: 30.0 + 33.0 = 63.0
      // Anna total: 20.0 + 36.6 = 56.6
      // Ben total: 10.0 + 40.8 = 50.8
      final theoMulti = multiLeaderboard.firstWhere((p) => p.uid == 'u1');
      final benMulti = multiLeaderboard.firstWhere((p) => p.uid == 'u4');
      expect(theoMulti.totalPoints, 70.0);
      expect(theoMulti.formattedTotalPoints, '70');
      expect(benMulti.totalPoints, closeTo(50.8, 0.01));
      expect(benMulti.formattedTotalPoints, '50.8');

      // Check stats without multipliers (standard mode):
      final totalStatsStandard = MarioKartGroupStats(
        games: [game1, game2],
        playerUids: ['u1', 'u2', 'u3', 'u4'],
        playerNames: ['Theo', 'Max', 'Anna', 'Ben'],
        useMultipliers: false,
      );
      final standardLeaderboard = totalStatsStandard.leaderboard;
      // Theo: 40 + 30 = 70
      // Ben: 10 + 30 = 40 (instead of 50.8)
      final benStandard = standardLeaderboard.firstWhere((p) => p.uid == 'u4');
      expect(benStandard.totalPoints, 40.0);
    });
  });
}

