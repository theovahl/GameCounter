import 'package:cloud_firestore/cloud_firestore.dart';

// GeoGuessr: mehrere Stufen (z.B. Weltkarte, No-Move, Deutschland), jeweils als Best of.
// Gezählt wird die Gesamtzahl der gewonnenen Runden über alle Stufen.

// Eines der beiden Teams
class GeoguessrTeam {
  final String name;
  final List<String> playerUids;
  final List<String> playerNames;

  GeoguessrTeam({
    required this.name,
    required this.playerUids,
    required this.playerNames,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'playerUids': playerUids,
      'playerNames': playerNames,
    };
  }

  factory GeoguessrTeam.fromMap(Map<String, dynamic> map) {
    return GeoguessrTeam(
      name: map['name'] ?? '',
      playerUids: List<String>.from(map['playerUids'] ?? []),
      playerNames: List<String>.from(map['playerNames'] ?? []),
    );
  }
}

// Eine Stufe, z.B. "Weltkarte · Bewegen" als BO3
class GeoguessrStage {
  final String title;
  final String details;
  final int winsNeeded; // 2 = BO3

  GeoguessrStage({required this.title, this.details = '', this.winsNeeded = 2});

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'details': details,
      'winsNeeded': winsNeeded,
    };
  }

  factory GeoguessrStage.fromMap(Map<String, dynamic> map) {
    return GeoguessrStage(
      title: map['title'] ?? '',
      details: map['details'] ?? '',
      winsNeeded: (map['winsNeeded'] as num?)?.toInt() ?? 2,
    );
  }
}

// Eine gespielte Runde: welches Team hat sie in welcher Stufe gewonnen?
class GeoguessrRound {
  final int winnerIndex; // 0 = Team 1, 1 = Team 2
  final int stageIndex;
  final DateTime? timestamp;

  GeoguessrRound({
    required this.winnerIndex,
    this.stageIndex = 0,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'winnerIndex': winnerIndex,
      'stageIndex': stageIndex,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : Timestamp.now(),
    };
  }

  factory GeoguessrRound.fromMap(Map<String, dynamic> map) {
    return GeoguessrRound(
      winnerIndex: (map['winnerIndex'] as num?)?.toInt() ?? 0,
      stageIndex: (map['stageIndex'] as num?)?.toInt() ?? 0,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) : null),
    );
  }
}

// Repräsentiert ein GeoGuessr-Spiel (immer 2 Teams)
class GeoguessrGame {
  final String? id; // Firestore Document ID
  final String createdBy;
  final DateTime date;
  final List<String> memberUids; // Alle Spieler + Ersteller (für Abfragen)
  final List<GeoguessrTeam> teams;
  final List<GeoguessrStage> stages;
  final List<GeoguessrRound> rounds;
  final String status; // 'active' | 'finished'

  GeoguessrGame({
    this.id,
    required this.createdBy,
    required this.date,
    required this.memberUids,
    required this.teams,
    required this.stages,
    List<GeoguessrRound>? rounds,
    this.status = 'active',
  }) : rounds = rounds ?? [];

  // Runden, die zählen: pro Stufe nur bis diese entschieden ist
  List<GeoguessrRound> get countedRounds {
    final stageWon = List.generate(stages.length, (_) => [0, 0]);
    final result = <GeoguessrRound>[];
    for (final round in rounds) {
      if (round.winnerIndex < 0 || round.winnerIndex > 1) continue;
      if (round.stageIndex < 0 || round.stageIndex >= stages.length) continue;
      final won = stageWon[round.stageIndex];
      if (won.any((w) => w >= stages[round.stageIndex].winsNeeded)) continue;
      won[round.winnerIndex]++;
      result.add(round);
    }
    return result;
  }

  /// Gewonnene Runden pro Team in einer Stufe
  List<int> stageWins(int stageIndex) {
    final won = [0, 0];
    for (final round in countedRounds) {
      if (round.stageIndex == stageIndex) won[round.winnerIndex]++;
    }
    return won;
  }

  bool isStageDone(int stageIndex) =>
      stageWins(stageIndex).any((w) => w >= stages[stageIndex].winsNeeded);

  /// Erste noch nicht entschiedene Stufe (null = alle gespielt)
  int? get currentStageIndex {
    for (int i = 0; i < stages.length; i++) {
      if (!isStageDone(i)) return i;
    }
    return null;
  }

  bool get isComplete => stages.isNotEmpty && currentStageIndex == null;

  /// Gesamtzahl gewonnener Runden pro Team über alle Stufen
  List<int> get wins {
    final won = [0, 0];
    for (final round in countedRounds) {
      won[round.winnerIndex]++;
    }
    return won;
  }

  /// Team mit mehr gewonnenen Runden, sobald alle Stufen gespielt sind
  /// (null = läuft noch oder Gleichstand)
  int? get winnerIndex {
    if (!isComplete) return null;
    final won = wins;
    if (won[0] > won[1]) return 0;
    if (won[1] > won[0]) return 1;
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'date': Timestamp.fromDate(date),
      'memberUids': memberUids,
      'teams': teams.map((t) => t.toMap()).toList(),
      'stages': stages.map((s) => s.toMap()).toList(),
      'rounds': rounds.map((r) => r.toMap()).toList(),
      'status': status,
    };
  }

  factory GeoguessrGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return GeoguessrGame.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory GeoguessrGame.fromMap(Map<String, dynamic> data, {String? id}) {
    final teamsRaw = (data['teams'] as List<dynamic>?) ?? [];
    final stagesRaw = (data['stages'] as List<dynamic>?) ?? [];
    final roundsRaw = (data['rounds'] as List<dynamic>?) ?? [];
    final stages = stagesRaw
        .map((s) => GeoguessrStage.fromMap(Map<String, dynamic>.from(s as Map)))
        .toList();
    return GeoguessrGame(
      id: id,
      createdBy: data['createdBy'] ?? '',
      date: data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      memberUids: List<String>.from(data['memberUids'] ?? []),
      teams: teamsRaw.map((t) => GeoguessrTeam.fromMap(Map<String, dynamic>.from(t as Map))).toList(),
      // Ältere Spiele ohne Stufen: eine einzige Stufe mit dem damaligen Siegziel
      stages: stages.isNotEmpty
          ? stages
          : [GeoguessrStage(title: 'Best of', winsNeeded: (data['winsNeeded'] as num?)?.toInt() ?? 2)],
      rounds: roundsRaw.map((r) => GeoguessrRound.fromMap(Map<String, dynamic>.from(r as Map))).toList(),
      status: data['status'] ?? 'active',
    );
  }
}
