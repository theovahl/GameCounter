import 'package:cloud_firestore/cloud_firestore.dart';
import 'mariokart_data.dart';

class MarioKartCupInfo {
  final String cupId;
  final String cupName;
  final List<String> tracks;

  const MarioKartCupInfo({
    required this.cupId,
    required this.cupName,
    required this.tracks,
  });

  Map<String, dynamic> toMap() {
    return {
      'cupId': cupId,
      'cupName': cupName,
      'tracks': tracks,
    };
  }

  factory MarioKartCupInfo.fromMap(Map<String, dynamic> map) {
    return MarioKartCupInfo(
      cupId: map['cupId'] ?? '',
      cupName: map['cupName'] ?? '',
      tracks: List<String>.from(map['tracks'] ?? []),
    );
  }
}

class MarioKartGroup {
  final String? id;
  final String name;
  final String createdBy;
  final List<String> playerUids;
  final List<String> playerNames;
  final DateTime createdAt;

  MarioKartGroup({
    this.id,
    required this.name,
    required this.createdBy,
    required this.playerUids,
    required this.playerNames,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'playerUids': playerUids,
      'playerNames': playerNames,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MarioKartGroup.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MarioKartGroup(
      id: doc.id,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      playerUids: List<String>.from(data['playerUids'] ?? []),
      playerNames: List<String>.from(data['playerNames'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory MarioKartGroup.fromMap(Map<String, dynamic> map, {String? id}) {
    return MarioKartGroup(
      id: id ?? map['id'],
      name: map['name'] ?? '',
      createdBy: map['createdBy'] ?? '',
      playerUids: List<String>.from(map['playerUids'] ?? []),
      playerNames: List<String>.from(map['playerNames'] ?? []),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarioKartGroup && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MarioKartRace {
  final int cupIndex; // Index des Cups im Match (0, 1, 2...)
  final int trackIndex; // 0, 1, 2, 3 (innerhalb dieses Cups)
  final String trackName;
  final Map<String, int> placements; // UID -> Platzierung (1..N)
  final Map<String, int> points; // UID -> Punkte (15, 12, 10...)
  final DateTime? timestamp;

  MarioKartRace({
    this.cupIndex = 0,
    required this.trackIndex,
    required this.trackName,
    required this.placements,
    required this.points,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'cupIndex': cupIndex,
      'trackIndex': trackIndex,
      'trackName': trackName,
      'placements': placements,
      'points': points,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : Timestamp.now(),
    };
  }

  factory MarioKartRace.fromMap(Map<String, dynamic> map) {
    final rawPlacements = map['placements'] as Map<String, dynamic>? ?? {};
    final placements = rawPlacements.map((k, v) => MapEntry(k, (v as num).toInt()));

    final rawPoints = map['points'] as Map<String, dynamic>? ?? {};
    final points = rawPoints.map((k, v) => MapEntry(k, (v as num).toInt()));

    return MarioKartRace(
      cupIndex: map['cupIndex'] ?? 0,
      trackIndex: map['trackIndex'] ?? 0,
      trackName: map['trackName'] ?? '',
      placements: placements,
      points: points,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) : null),
    );
  }
}

class MarioKartGame {
  final String? id;
  final String groupId;
  final String groupName;
  final List<MarioKartCupInfo> cups; // Liste aller gespielten / aktiven Cups
  final String createdBy;
  final DateTime date;
  final List<String> playerUids;
  final List<String> playerNames;
  final List<MarioKartRace> races;
  final Map<String, int> totalScores; // UID -> Gesamtpunkte über alle Cups
  final String status; // 'active' | 'finished'
  final bool hasMultipliers; // Wurde das Spiel mit Multiplikatoren beendet?
  final Map<String, double> appliedMultipliers; // UID -> Multiplikator (1.0, 1.1, ...)
  final Map<String, double> modifiedTotalScores; // UID -> modifizierte Endpunkte

  MarioKartGame({
    this.id,
    required this.groupId,
    required this.groupName,
    List<MarioKartCupInfo>? cups,
    String? cupId,
    String? cupName,
    List<String>? cupTracks,
    required this.createdBy,
    required this.date,
    required this.playerUids,
    required this.playerNames,
    List<MarioKartRace>? races,
    Map<String, int>? totalScores,
    this.status = 'active',
    this.hasMultipliers = false,
    Map<String, double>? appliedMultipliers,
    Map<String, double>? modifiedTotalScores,
  })  : cups = cups ??
            (cupId != null
                ? [
                    MarioKartCupInfo(
                      cupId: cupId,
                      cupName: cupName ?? '',
                      tracks: cupTracks ?? [],
                    )
                  ]
                : []),
        races = races ?? [],
        totalScores = totalScores ?? {},
        appliedMultipliers = appliedMultipliers ?? {},
        modifiedTotalScores = modifiedTotalScores ?? {};

  // Bequeme Getter für den aktuellen (zuletzt hinzugefügten) Cup
  int get activeCupIndex => cups.isNotEmpty ? cups.length - 1 : 0;
  MarioKartCupInfo get activeCup => cups.isNotEmpty
      ? cups.last
      : const MarioKartCupInfo(cupId: '', cupName: '', tracks: []);

  String get cupId => activeCup.cupId;
  String get cupName => activeCup.cupName;
  List<String> get cupTracks => activeCup.tracks;

  /// Liefert alle gefahrenen Rennen für einen bestimmten Cup
  List<MarioKartRace> racesForCup(int cIndex) {
    return races.where((r) => r.cupIndex == cIndex).toList();
  }

  /// Anzahl der Strecken eines Cups (4 bei normalen Cups, bei eigener Streckenauswahl beliebig)
  int trackCountForCup(int cIndex) {
    if (cIndex < cups.length && cups[cIndex].tracks.isNotEmpty) {
      return cups[cIndex].tracks.length;
    }
    return 4;
  }

  /// Prüft, ob ein Cup mit allen Strecken absolviert wurde
  bool isCupFinished(int cIndex) {
    return racesForCup(cIndex).length >= trackCountForCup(cIndex);
  }

  /// Prüft, ob der aktuell aktive Cup abgeschlossen ist
  bool get isActiveCupFinished => isCupFinished(activeCupIndex);

  /// Gibt den Namen eines Spielers anhand seiner UID zurück
  String getPlayerName(String uid) {
    final index = playerUids.indexOf(uid);
    if (index >= 0 && index < playerNames.length) {
      return playerNames[index];
    }
    return 'Spieler';
  }

  /// Berechnet die Gesamtpunktzahl aller Spieler aus allen Rennen über alle Cups
  Map<String, int> get calculatedTotalScores {
    final totals = <String, int>{};
    for (var uid in playerUids) {
      totals[uid] = 0;
    }
    for (var race in races) {
      race.points.forEach((uid, pts) {
        totals[uid] = (totals[uid] ?? 0) + pts;
      });
    }
    return totals;
  }

  /// Gibt die Spieler-UIDs sortiert nach ihren Gesamtpunkten zurück (Höchste Punkte zuerst)
  List<String> get rankedPlayerUids {
    final scores = calculatedTotalScores;
    final sortedUids = List<String>.from(playerUids);
    sortedUids.sort((a, b) {
      final scoreA = scores[a] ?? 0;
      final scoreB = scores[b] ?? 0;
      return scoreB.compareTo(scoreA); // Absteigend
    });
    return sortedUids;
  }

  /// Gibt die Spieler-UIDs sortiert nach ihren modifizierten Gesamtpunkten zurück (bei Multiplikatoren)
  List<String> get rankedModifiedPlayerUids {
    final scores = modifiedTotalScores.isNotEmpty
        ? modifiedTotalScores
        : calculatedTotalScores.map((k, v) => MapEntry(k, v.toDouble()));
    final sortedUids = List<String>.from(playerUids);
    sortedUids.sort((a, b) {
      final scoreA = scores[a] ?? 0.0;
      final scoreB = scores[b] ?? 0.0;
      return scoreB.compareTo(scoreA);
    });
    return sortedUids;
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'cups': cups.map((c) => c.toMap()).toList(),
      'cupId': cupId,
      'cupName': cupName,
      'cupTracks': cupTracks,
      'createdBy': createdBy,
      'date': Timestamp.fromDate(date),
      'playerUids': playerUids,
      'playerNames': playerNames,
      'races': races.map((r) => r.toMap()).toList(),
      'totalScores': totalScores,
      'status': status,
      'hasMultipliers': hasMultipliers,
      'appliedMultipliers': appliedMultipliers,
      'modifiedTotalScores': modifiedTotalScores,
    };
  }

  factory MarioKartGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    List<MarioKartCupInfo> cupsList = [];
    if (data['cups'] is List && (data['cups'] as List).isNotEmpty) {
      cupsList = (data['cups'] as List)
          .map((c) => MarioKartCupInfo.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList();
    } else if (data['cupId'] != null) {
      cupsList = [
        MarioKartCupInfo(
          cupId: data['cupId'] ?? '',
          cupName: data['cupName'] ?? '',
          tracks: List<String>.from(data['cupTracks'] ?? []),
        ),
      ];
    }

    final rawRaces = (data['races'] as List<dynamic>?) ?? [];
    final racesList = rawRaces
        .map((r) => MarioKartRace.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();

    final rawScores = (data['totalScores'] as Map<String, dynamic>?) ?? {};
    final scoresMap = rawScores.map((k, v) => MapEntry(k, (v as num).toInt()));

    final rawApplied = (data['appliedMultipliers'] as Map<String, dynamic>?) ?? {};
    final appliedMap = rawApplied.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final rawModified = (data['modifiedTotalScores'] as Map<String, dynamic>?) ?? {};
    final modifiedMap = rawModified.map((k, v) => MapEntry(k, (v as num).toDouble()));

    return MarioKartGame(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? '',
      cups: cupsList,
      createdBy: data['createdBy'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      playerUids: List<String>.from(data['playerUids'] ?? []),
      playerNames: List<String>.from(data['playerNames'] ?? []),
      races: racesList,
      totalScores: scoresMap,
      status: data['status'] ?? 'active',
      hasMultipliers: data['hasMultipliers'] ?? false,
      appliedMultipliers: appliedMap,
      modifiedTotalScores: modifiedMap,
    );
  }
}

class PlayerGroupStats {
  final String uid;
  final String name;
  final double totalPoints;
  final int racesCount;
  final int wins; // 1. Platz
  final int secondPlaces; // 2. Platz
  final int thirdPlaces; // 3. Platz
  final int matchWins; // Gesamtsieg in Matches
  final int matchesPlayed;
  final double bestMatchScore;

  PlayerGroupStats({
    required this.uid,
    required this.name,
    this.totalPoints = 0.0,
    this.racesCount = 0,
    this.wins = 0,
    this.secondPlaces = 0,
    this.thirdPlaces = 0,
    this.matchWins = 0,
    this.matchesPlayed = 0,
    this.bestMatchScore = 0.0,
  });

  String get formattedTotalPoints {
    if (totalPoints % 1 == 0) {
      return totalPoints.toInt().toString();
    }
    return totalPoints.toStringAsFixed(1);
  }

  String get formattedBestMatchScore {
    if (bestMatchScore % 1 == 0) {
      return bestMatchScore.toInt().toString();
    }
    return bestMatchScore.toStringAsFixed(1);
  }

  double get avgPointsPerRace =>
      racesCount > 0 ? (totalPoints / racesCount) : 0.0;
  double get winRatePercentage =>
      racesCount > 0 ? ((wins / racesCount) * 100) : 0.0;
  double get podiumPercentage =>
      racesCount > 0 ? (((wins + secondPlaces + thirdPlaces) / racesCount) * 100) : 0.0;
}

class ProgressionPoint {
  final String label;
  final Map<String, double> cumulativePoints;

  ProgressionPoint({
    required this.label,
    required this.cumulativePoints,
  });
}

class MarioKartGroupStats {
  final List<MarioKartGame> games; // chronologisch aufsteigend sortiert
  final List<String> playerUids;
  final List<String> playerNames;
  final bool useMultipliers;

  MarioKartGroupStats({
    required this.games,
    required this.playerUids,
    required this.playerNames,
    this.useMultipliers = false,
  });

  String getPlayerName(String uid) {
    final idx = playerUids.indexOf(uid);
    if (idx != -1 && idx < playerNames.length) {
      return playerNames[idx];
    }
    for (final g in games) {
      final gIdx = g.playerUids.indexOf(uid);
      if (gIdx != -1 && gIdx < g.playerNames.length) {
        return g.playerNames[gIdx];
      }
    }
    return uid.length > 5 ? uid.substring(0, 5) : uid;
  }

  int get totalRaces => games.fold(0, (total, g) => total + g.races.length);

  int get totalMatches => games.length;

  int get finishedMatches => games.where((g) => g.status == 'finished').length;

  /// Liefert die Allzeit-Tabelle (Leaderboard) sortiert nach Gesamtpunkten
  List<PlayerGroupStats> get leaderboard {
    // Sammle alle beteiligten UIDs
    final allUids = <String>{...playerUids};
    for (final g in games) {
      allUids.addAll(g.playerUids);
    }

    final pointsMap = <String, double>{for (var u in allUids) u: 0.0};
    final racesMap = <String, int>{for (var u in allUids) u: 0};
    final winsMap = <String, int>{for (var u in allUids) u: 0};
    final secondMap = <String, int>{for (var u in allUids) u: 0};
    final thirdMap = <String, int>{for (var u in allUids) u: 0};
    final matchWinsMap = <String, int>{for (var u in allUids) u: 0};
    final matchesPlayedMap = <String, int>{for (var u in allUids) u: 0};
    final bestMatchMap = <String, double>{for (var u in allUids) u: 0.0};

    for (final game in games) {
      // Wenn useMultipliers aktiv ist UND das Spiel Multiplikatoren hat, nutzen wir die modifizierten Scores
      final Map<String, double> gameScores;
      if (useMultipliers && game.hasMultipliers && game.modifiedTotalScores.isNotEmpty) {
        gameScores = game.modifiedTotalScores;
      } else {
        gameScores = game.calculatedTotalScores.map((k, v) => MapEntry(k, v.toDouble()));
      }

      for (final uid in game.playerUids) {
        matchesPlayedMap[uid] = (matchesPlayedMap[uid] ?? 0) + 1;
        final score = gameScores[uid] ?? 0.0;
        if (score > (bestMatchMap[uid] ?? 0.0)) {
          bestMatchMap[uid] = score;
        }
      }

      // Match-Gewinner ermitteln
      if (gameScores.isNotEmpty) {
        double highestScore = -1.0;
        for (final score in gameScores.values) {
          if (score > highestScore) highestScore = score;
        }
        if (highestScore > 0.0) {
          for (final entry in gameScores.entries) {
            if (entry.value == highestScore) {
              matchWinsMap[entry.key] = (matchWinsMap[entry.key] ?? 0) + 1;
            }
          }
        }
      }

      // Rennen analysieren
      for (final race in game.races) {
        for (final entry in race.points.entries) {
          final uid = entry.key;
          final double pts;
          if (useMultipliers && game.hasMultipliers) {
            final mult = game.appliedMultipliers[uid] ?? 1.0;
            pts = entry.value * mult;
          } else {
            pts = entry.value.toDouble();
          }

          pointsMap[uid] = (pointsMap[uid] ?? 0.0) + pts;
          racesMap[uid] = (racesMap[uid] ?? 0) + 1;

          final placement = race.placements[uid];
          if (placement == 1) {
            winsMap[uid] = (winsMap[uid] ?? 0) + 1;
          } else if (placement == 2) {
            secondMap[uid] = (secondMap[uid] ?? 0) + 1;
          } else if (placement == 3) {
            thirdMap[uid] = (thirdMap[uid] ?? 0) + 1;
          }
        }
      }
    }

    final statsList = allUids.map((uid) {
      return PlayerGroupStats(
        uid: uid,
        name: getPlayerName(uid),
        totalPoints: pointsMap[uid] ?? 0.0,
        racesCount: racesMap[uid] ?? 0,
        wins: winsMap[uid] ?? 0,
        secondPlaces: secondMap[uid] ?? 0,
        thirdPlaces: thirdMap[uid] ?? 0,
        matchWins: matchWinsMap[uid] ?? 0,
        matchesPlayed: matchesPlayedMap[uid] ?? 0,
        bestMatchScore: bestMatchMap[uid] ?? 0.0,
      );
    }).toList();

    statsList.sort((a, b) {
      final cmpPoints = b.totalPoints.compareTo(a.totalPoints);
      if (cmpPoints != 0) return cmpPoints;
      final cmpWins = b.wins.compareTo(a.wins);
      if (cmpWins != 0) return cmpWins;
      return b.avgPointsPerRace.compareTo(a.avgPointsPerRace);
    });

    return statsList;
  }

  /// Kumulativer Punkteverlauf nach jedem einzelnen Rennen
  List<ProgressionPoint> get raceProgression {
    final allUids = <String>{...playerUids};
    for (final g in games) {
      allUids.addAll(g.playerUids);
    }

    final currentScores = <String, double>{for (var u in allUids) u: 0.0};
    final points = <ProgressionPoint>[
      ProgressionPoint(
        label: 'Start',
        cumulativePoints: Map.from(currentScores),
      ),
    ];

    int raceNumber = 1;
    for (final game in games) {
      for (final race in game.races) {
        for (final entry in race.points.entries) {
          final uid = entry.key;
          final double pts;
          if (useMultipliers && game.hasMultipliers) {
            final mult = game.appliedMultipliers[uid] ?? 1.0;
            pts = entry.value * mult;
          } else {
            pts = entry.value.toDouble();
          }
          currentScores[uid] = (currentScores[uid] ?? 0.0) + pts;
        }
        final label = race.trackName.isNotEmpty ? race.trackName : 'R$raceNumber';
        points.add(ProgressionPoint(
          label: label,
          cumulativePoints: Map.from(currentScores),
        ));
        raceNumber++;
      }
    }

    return points;
  }

  /// Kumulativer Punkteverlauf nach jedem Match
  List<ProgressionPoint> get matchProgression {
    final allUids = <String>{...playerUids};
    for (final g in games) {
      allUids.addAll(g.playerUids);
    }

    final currentScores = <String, double>{for (var u in allUids) u: 0.0};
    final points = <ProgressionPoint>[
      ProgressionPoint(
        label: 'Start',
        cumulativePoints: Map.from(currentScores),
      ),
    ];

    int matchIndex = 1;
    for (final game in games) {
      final Map<String, double> gameScores;
      if (useMultipliers && game.hasMultipliers && game.modifiedTotalScores.isNotEmpty) {
        gameScores = game.modifiedTotalScores;
      } else {
        gameScores = game.calculatedTotalScores.map((k, v) => MapEntry(k, v.toDouble()));
      }

      for (final entry in gameScores.entries) {
        currentScores[entry.key] = (currentScores[entry.key] ?? 0.0) + entry.value;
      }
      points.add(ProgressionPoint(
        label: 'M$matchIndex',
        cumulativePoints: Map.from(currentScores),
      ));
      matchIndex++;
    }

    return points;
  }

  /// Berechnet die Multiplikatoren für die Teilnehmer eines Matches
  /// basierend auf dem aktuellen Stand der Multiplikatoren-All-Time-Tabelle.
  Map<String, double> calculateMultipliersForMatch(List<String> matchPlayerUids) {
    final finishedGames = games.where((g) => g.status == 'finished').toList();
    final multiStats = MarioKartGroupStats(
      games: finishedGames,
      playerUids: playerUids,
      playerNames: playerNames,
      useMultipliers: true,
    );
    final board = multiStats.leaderboard;

    final participants = List<String>.from(matchPlayerUids);

    // Sortieren nach aktuellem Gesamtpunktestand in der Multiplikator-Tabelle
    participants.sort((a, b) {
      final statA = board.firstWhere((p) => p.uid == a, orElse: () => PlayerGroupStats(uid: a, name: ''));
      final statB = board.firstWhere((p) => p.uid == b, orElse: () => PlayerGroupStats(uid: b, name: ''));
      final cmp = statB.totalPoints.compareTo(statA.totalPoints);
      if (cmp != 0) return cmp;
      return statB.wins.compareTo(statA.wins);
    });

    final result = <String, double>{};
    int currentRank = 1;
    double? lastPoints;

    for (int i = 0; i < participants.length; i++) {
      final uid = participants[i];
      final stat = board.firstWhere((p) => p.uid == uid, orElse: () => PlayerGroupStats(uid: uid, name: ''));

      // Wenn noch keine Punkte in der Gruppe existieren, starten alle gleich mit Multiplikator 1.0
      if (stat.totalPoints == 0.0 && (i == 0 || lastPoints == 0.0)) {
        result[uid] = 1.0;
        lastPoints = 0.0;
        continue;
      }

      if (lastPoints != null && stat.totalPoints < lastPoints) {
        currentRank = i + 1;
      }
      lastPoints = stat.totalPoints;
      result[uid] = MarioKartData.getMultiplierForRank(currentRank);
    }

    return result;
  }
}
