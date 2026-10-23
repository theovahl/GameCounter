import 'package:cloud_firestore/cloud_firestore.dart';

// Ein Team mit seinen Spielern
class BouleTeam {
  final String name;
  final List<String> playerUids;
  final List<String> playerNames;

  BouleTeam({
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

  factory BouleTeam.fromMap(Map<String, dynamic> map) {
    return BouleTeam(
      name: map['name'] ?? '',
      playerUids: List<String>.from(map['playerUids'] ?? []),
      playerNames: List<String>.from(map['playerNames'] ?? []),
    );
  }
}

// Eine Aufnahme (Mène): ein Team bekommt Punkte
class BouleEnd {
  final int teamIndex;
  final int points;
  final DateTime? timestamp;

  BouleEnd({
    required this.teamIndex,
    required this.points,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'teamIndex': teamIndex,
      'points': points,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : Timestamp.now(),
    };
  }

  factory BouleEnd.fromMap(Map<String, dynamic> map) {
    return BouleEnd(
      teamIndex: (map['teamIndex'] as num?)?.toInt() ?? 0,
      points: (map['points'] as num?)?.toInt() ?? 0,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) : null),
    );
  }
}

// Berechneter Stand eines Satzes (wird nicht gespeichert)
class BouleSet {
  final int setNumber;
  final List<int> scores;
  final List<int> endIndices; // Indizes der Aufnahmen in BouleGame.ends
  final int? winnerTeam; // null = Satz läuft noch

  BouleSet({
    required this.setNumber,
    required this.scores,
    required this.endIndices,
    this.winnerTeam,
  });

  bool get isFinished => winnerTeam != null;
}

// Repräsentiert das gesamte Boule-Spiel
class BouleGame {
  final String? id; // Firestore Document ID
  final String createdBy;
  final DateTime date;
  final List<String> memberUids; // Alle Spieler + Ersteller (für Abfragen)
  final List<BouleTeam> teams;
  final int pointsPerSet;
  final int setsToWin;
  final List<BouleEnd> ends;
  final String status; // 'active' | 'finished'

  BouleGame({
    this.id,
    required this.createdBy,
    required this.date,
    required this.memberUids,
    required this.teams,
    this.pointsPerSet = 13,
    this.setsToWin = 1,
    List<BouleEnd>? ends,
    this.status = 'active',
  }) : ends = ends ?? [];

  // Rechnet alle Aufnahmen in Sätze um. Der letzte Satz ist ggf. noch offen.
  // Aufnahmen nach Spielende werden ignoriert.
  List<BouleSet> get sets {
    final result = <BouleSet>[];
    final setsWon = List<int>.filled(teams.length, 0);
    var scores = List<int>.filled(teams.length, 0);
    var endIndices = <int>[];

    for (int i = 0; i < ends.length; i++) {
      if (setsWon.any((w) => w >= setsToWin)) break;
      final end = ends[i];
      if (end.teamIndex < 0 || end.teamIndex >= teams.length) continue;

      scores[end.teamIndex] += end.points;
      endIndices.add(i);

      if (scores[end.teamIndex] >= pointsPerSet) {
        setsWon[end.teamIndex]++;
        result.add(BouleSet(
          setNumber: result.length + 1,
          scores: scores,
          endIndices: endIndices,
          winnerTeam: end.teamIndex,
        ));
        scores = List<int>.filled(teams.length, 0);
        endIndices = <int>[];
      }
    }

    if (!setsWon.any((w) => w >= setsToWin)) {
      result.add(BouleSet(
        setNumber: result.length + 1,
        scores: scores,
        endIndices: endIndices,
      ));
    }
    return result;
  }

  List<int> get setsWon {
    final won = List<int>.filled(teams.length, 0);
    for (final s in sets) {
      if (s.winnerTeam != null) won[s.winnerTeam!]++;
    }
    return won;
  }

  // Team, das das Spiel gewonnen hat (null = noch kein Sieger)
  int? get winnerTeam {
    final won = setsWon;
    for (int i = 0; i < won.length; i++) {
      if (won[i] >= setsToWin) return i;
    }
    return null;
  }

  // Der aktuell laufende Satz (oder der letzte, falls das Spiel entschieden ist)
  BouleSet get currentSet => sets.last;

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'date': Timestamp.fromDate(date),
      'memberUids': memberUids,
      'teams': teams.map((t) => t.toMap()).toList(),
      'pointsPerSet': pointsPerSet,
      'setsToWin': setsToWin,
      'ends': ends.map((e) => e.toMap()).toList(),
      'status': status,
    };
  }

  factory BouleGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return BouleGame.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory BouleGame.fromMap(Map<String, dynamic> data, {String? id}) {
    final teamsRaw = (data['teams'] as List<dynamic>?) ?? [];
    final endsRaw = (data['ends'] as List<dynamic>?) ?? [];

    return BouleGame(
      id: id,
      createdBy: data['createdBy'] ?? '',
      date: data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      memberUids: List<String>.from(data['memberUids'] ?? []),
      teams: teamsRaw.map((t) => BouleTeam.fromMap(Map<String, dynamic>.from(t as Map))).toList(),
      pointsPerSet: (data['pointsPerSet'] as num?)?.toInt() ?? 13,
      setsToWin: (data['setsToWin'] as num?)?.toInt() ?? 1,
      ends: endsRaw.map((e) => BouleEnd.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      status: data['status'] ?? 'active',
    );
  }
}
