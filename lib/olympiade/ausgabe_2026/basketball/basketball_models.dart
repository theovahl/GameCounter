import 'package:cloud_firestore/cloud_firestore.dart';

// Eines der beiden Teams 
class BasketballTeam {
  final String name;
  final List<String> playerUids;
  final List<String> playerNames;

  BasketballTeam({
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

  factory BasketballTeam.fromMap(Map<String, dynamic> map) {
    return BasketballTeam(
      name: map['name'] ?? '',
      playerUids: List<String>.from(map['playerUids'] ?? []),
      playerNames: List<String>.from(map['playerNames'] ?? []),
    );
  }
}

// Eine gespielte Partie: welches Team hat gewonnen?
class BasketballRound {
  final int winnerIndex; // 0 = Team 1, 1 = Team 2
  final DateTime? timestamp;

  BasketballRound({
    required this.winnerIndex,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'winnerIndex': winnerIndex,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : Timestamp.now(),
    };
  }

  factory BasketballRound.fromMap(Map<String, dynamic> map) {
    return BasketballRound(
      winnerIndex: (map['winnerIndex'] as num?)?.toInt() ?? 0,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) : null),
    );
  }
}

// Repräsentiert ein Basketball-Spiel im Best-of-Modus (immer 2 Teams)
class BasketballGame {
  final String? id; // Firestore Document ID
  final String createdBy;
  final DateTime date;
  final List<String> memberUids; // Alle Spieler + Ersteller (für Abfragen)
  final List<BasketballTeam> teams;
  final int winsNeeded;
  final List<BasketballRound> rounds;
  final String status; // 'active' | 'finished'

  BasketballGame({
    this.id,
    required this.createdBy,
    required this.date,
    required this.memberUids,
    required this.teams,
    this.winsNeeded = 3,
    List<BasketballRound>? rounds,
    this.status = 'active',
  }) : rounds = rounds ?? [];

  // Partien, die tatsächlich zählen (alles nach Spielende wird ignoriert)
  List<BasketballRound> get countedRounds {
    final won = [0, 0];
    final result = <BasketballRound>[];
    for (final round in rounds) {
      if (won.any((w) => w >= winsNeeded)) break;
      if (round.winnerIndex < 0 || round.winnerIndex > 1) continue;
      won[round.winnerIndex]++;
      result.add(round);
    }
    return result;
  }

  List<int> get wins {
    final won = [0, 0];
    for (final round in countedRounds) {
      won[round.winnerIndex]++;
    }
    return won;
  }

  // Team, das das Spiel gewonnen hat (null = läuft noch)
  int? get winnerIndex {
    final won = wins;
    for (int i = 0; i < 2; i++) {
      if (won[i] >= winsNeeded) return i;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'date': Timestamp.fromDate(date),
      'memberUids': memberUids,
      'teams': teams.map((t) => t.toMap()).toList(),
      'winsNeeded': winsNeeded,
      'rounds': rounds.map((r) => r.toMap()).toList(),
      'status': status,
    };
  }

  factory BasketballGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return BasketballGame.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory BasketballGame.fromMap(Map<String, dynamic> data, {String? id}) {
    final teamsRaw = (data['teams'] as List<dynamic>?) ?? [];
    final roundsRaw = (data['rounds'] as List<dynamic>?) ?? [];
    return BasketballGame(
      id: id,
      createdBy: data['createdBy'] ?? '',
      date: data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      memberUids: List<String>.from(data['memberUids'] ?? []),
      teams: teamsRaw.map((t) => BasketballTeam.fromMap(Map<String, dynamic>.from(t as Map))).toList(),
      winsNeeded: (data['winsNeeded'] as num?)?.toInt() ?? 3,
      rounds: roundsRaw.map((r) => BasketballRound.fromMap(Map<String, dynamic>.from(r as Map))).toList(),
      status: data['status'] ?? 'active',
    );
  }
}
