import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerGroup {
  final String? id; // Firestore Document ID
  final String name;
  final String createdBy;
  final List<String> playerUids; // Die 4 UIDs der Spieler
  final List<String> playerNames; // Die 4 Spielernamen
  final DateTime createdAt;

  PlayerGroup({
    this.id,
    required this.name,
    required this.createdBy,
    required this.playerUids,
    required this.playerNames,
    required this.createdAt,
  });

  // Alias für bestehenden Code
  List<String> get players => playerNames;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'playerUids': playerUids,
      'playerNames': playerNames,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PlayerGroup.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PlayerGroup(
      id: doc.id,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      playerUids: List<String>.from(data['playerUids'] ?? []),
      playerNames: List<String>.from(data['playerNames'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory PlayerGroup.fromMap(Map<String, dynamic> map, {String? id}) {
    return PlayerGroup(
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
      other is PlayerGroup && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Repräsentiert eine einzelne gespielte Runde
class GameRound {
  final int roundNumber;
  final List<int> scores; // Die Punkte für die 4 Spieler, z.B. [3, 3, -3, -3]
  final DateTime? timestamp;

  GameRound({
    required this.roundNumber,
    required this.scores,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'roundNumber': roundNumber,
      'scores': scores,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : Timestamp.now(),
    };
  }

  factory GameRound.fromMap(Map<String, dynamic> map) {
    return GameRound(
      roundNumber: map['roundNumber'] ?? 0,
      scores: (map['scores'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0, 0, 0],
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) : null),
    );
  }
}

// Repräsentiert das gesamte Spiel
class DoppelkopfGame {
  final String? id; // Firestore Document ID
  final String groupId; // Verknüpfung: Zu welcher Gruppe gehört dieses Spiel?
  final String groupName;
  final String createdBy;
  final DateTime date;
  final List<String> playerUids;
  final List<String> playerNames;
  final List<GameRound> rounds;
  final List<int> totalScores;
  final String status; // 'active' | 'finished'

  DoppelkopfGame({
    this.id,
    required this.groupId,
    this.groupName = '',
    required this.createdBy,
    required this.date,
    required this.playerUids,
    required this.playerNames,
    List<GameRound>? rounds,
    List<int>? totalScores,
    this.status = 'active',
  })  : rounds = rounds ?? [],
        totalScores = totalScores ?? [0, 0, 0, 0];

  // Alias für Abwärtskompatibilität
  List<String> get players => playerNames;

  // Berechnet live die aktuellen Gesamtpunkte aller Spieler aus den Runden
  List<int> get calculatedTotalScores {
    List<int> totals = [0, 0, 0, 0];
    for (var round in rounds) {
      for (int i = 0; i < 4; i++) {
        if (i < round.scores.length) {
          totals[i] += round.scores[i];
        }
      }
    }
    return totals;
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'createdBy': createdBy,
      'date': Timestamp.fromDate(date),
      'playerUids': playerUids,
      'playerNames': playerNames,
      'rounds': rounds.map((r) => r.toMap()).toList(),
      'totalScores': totalScores,
      'status': status,
    };
  }

  factory DoppelkopfGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final roundsRaw = (data['rounds'] as List<dynamic>?) ?? [];
    final roundsList = roundsRaw
        .map((r) => GameRound.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();

    final totalScoresRaw = (data['totalScores'] as List<dynamic>?) ?? [];
    final totalScoresList = totalScoresRaw.map((e) => (e as num).toInt()).toList();

    return DoppelkopfGame(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? '',
      createdBy: data['createdBy'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      playerUids: List<String>.from(data['playerUids'] ?? []),
      playerNames: List<String>.from(data['playerNames'] ?? []),
      rounds: roundsList,
      totalScores: totalScoresList.length == 4 ? totalScoresList : null,
      status: data['status'] ?? 'active',
    );
  }
}