import 'package:cloud_firestore/cloud_firestore.dart';

// Ein gespieltes Leg: wer hat es gewonnen?
class DartsLeg {
  final int winnerIndex; // 0 oder 1
  final DateTime? timestamp;

  DartsLeg({
    required this.winnerIndex,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'winnerIndex': winnerIndex,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : Timestamp.now(),
    };
  }

  factory DartsLeg.fromMap(Map<String, dynamic> map) {
    return DartsLeg(
      winnerIndex: (map['winnerIndex'] as num?)?.toInt() ?? 0,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) : null),
    );
  }
}

// Repräsentiert ein Dart-Match (immer 1 gegen 1)
class DartsGame {
  final String? id; // Firestore Document ID
  final String createdBy;
  final DateTime date;
  final List<String> playerUids; // Genau 2 Spieler
  final List<String> playerNames;
  final int legsToWin;
  final List<DartsLeg> legs;
  final String status; // 'active' | 'finished'

  DartsGame({
    this.id,
    required this.createdBy,
    required this.date,
    required this.playerUids,
    required this.playerNames,
    this.legsToWin = 3,
    List<DartsLeg>? legs,
    this.status = 'active',
  }) : legs = legs ?? [];

  // Legs, die tatsächlich zählen (alles nach Spielende wird ignoriert)
  List<DartsLeg> get countedLegs {
    final won = [0, 0];
    final result = <DartsLeg>[];
    for (final leg in legs) {
      if (won.any((w) => w >= legsToWin)) break;
      if (leg.winnerIndex < 0 || leg.winnerIndex > 1) continue;
      won[leg.winnerIndex]++;
      result.add(leg);
    }
    return result;
  }

  List<int> get legsWon {
    final won = [0, 0];
    for (final leg in countedLegs) {
      won[leg.winnerIndex]++;
    }
    return won;
  }

  // Spieler, der das Match gewonnen hat (null = läuft noch)
  int? get winnerIndex {
    final won = legsWon;
    for (int i = 0; i < 2; i++) {
      if (won[i] >= legsToWin) return i;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'date': Timestamp.fromDate(date),
      'playerUids': playerUids,
      'playerNames': playerNames,
      'legsToWin': legsToWin,
      'legs': legs.map((l) => l.toMap()).toList(),
      'status': status,
    };
  }

  factory DartsGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return DartsGame.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory DartsGame.fromMap(Map<String, dynamic> data, {String? id}) {
    final legsRaw = (data['legs'] as List<dynamic>?) ?? [];
    return DartsGame(
      id: id,
      createdBy: data['createdBy'] ?? '',
      date: data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      playerUids: List<String>.from(data['playerUids'] ?? []),
      playerNames: List<String>.from(data['playerNames'] ?? []),
      legsToWin: (data['legsToWin'] as num?)?.toInt() ?? 3,
      legs: legsRaw.map((l) => DartsLeg.fromMap(Map<String, dynamic>.from(l as Map))).toList(),
      status: data['status'] ?? 'active',
    );
  }
}
