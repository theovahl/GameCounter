import 'package:cloud_firestore/cloud_firestore.dart';

// Das Große Teilen: Lebensmittel möglichst genau halbieren. Pro Lebensmittel trägt
// jede WG ihre Abweichung in Prozent ein, die kleinere Gesamtabweichung gewinnt.

// Eines der beiden Teams
class HalbierenTeam {
  final String name;
  final List<String> playerUids;
  final List<String> playerNames;

  HalbierenTeam({
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

  factory HalbierenTeam.fromMap(Map<String, dynamic> map) {
    return HalbierenTeam(
      name: map['name'] ?? '',
      playerUids: List<String>.from(map['playerUids'] ?? []),
      playerNames: List<String>.from(map['playerNames'] ?? []),
    );
  }
}

// Ein Lebensmittel im Ablauf, z.B. "Banane" im ersten Akt
class TeilenFood {
  final int act; // 0, 1, 2 ...
  final String actTitle; // "Erster Akt"
  final String? actNote; // z.B. "Nur schwache Hand"
  final String name;

  TeilenFood({
    required this.act,
    required this.actTitle,
    this.actNote,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'act': act,
      'actTitle': actTitle,
      'actNote': actNote,
      'name': name,
    };
  }

  factory TeilenFood.fromMap(Map<String, dynamic> map) {
    return TeilenFood(
      act: (map['act'] as num?)?.toInt() ?? 0,
      actTitle: map['actTitle'] ?? '',
      actNote: map['actNote'] as String?,
      name: map['name'] ?? '',
    );
  }
}

// Ergebnis einer WG bei einem Lebensmittel
class TeilenEntry {
  final int foodIndex;
  final int teamIndex; // 0 oder 1
  final double deviation; // Abweichung in Prozent
  final String? cutterUid; // Wer hat zerteilt?
  final String? cutterName;
  final DateTime? timestamp;

  TeilenEntry({
    required this.foodIndex,
    required this.teamIndex,
    required this.deviation,
    this.cutterUid,
    this.cutterName,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'foodIndex': foodIndex,
      'teamIndex': teamIndex,
      'deviation': deviation,
      'cutterUid': cutterUid,
      'cutterName': cutterName,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : Timestamp.now(),
    };
  }

  factory TeilenEntry.fromMap(Map<String, dynamic> map) {
    return TeilenEntry(
      foodIndex: (map['foodIndex'] as num?)?.toInt() ?? 0,
      teamIndex: (map['teamIndex'] as num?)?.toInt() ?? 0,
      deviation: (map['deviation'] as num?)?.toDouble() ?? 0,
      cutterUid: map['cutterUid'] as String?,
      cutterName: map['cutterName'] as String?,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) : null),
    );
  }
}

// Repräsentiert ein Spiel "Das Große Teilen" (immer 2 Teams)
class HalbierenGame {
  final String? id; // Firestore Document ID
  final String createdBy;
  final DateTime date;
  final List<String> memberUids; // Alle Spieler + Ersteller (für Abfragen)
  final List<HalbierenTeam> teams;
  final List<TeilenFood> foods;
  final int secondsPerFood; // Zeitlimit pro Lebensmittel
  final List<TeilenEntry> entries;
  final String status; // 'active' | 'finished'

  HalbierenGame({
    this.id,
    required this.createdBy,
    required this.date,
    required this.memberUids,
    required this.teams,
    required this.foods,
    this.secondsPerFood = 180,
    List<TeilenEntry>? entries,
    this.status = 'active',
  }) : entries = entries ?? [];

  /// Eintrag einer WG für ein Lebensmittel (null = noch nicht eingetragen)
  TeilenEntry? entryFor(int foodIndex, int teamIndex) {
    for (final e in entries) {
      if (e.foodIndex == foodIndex && e.teamIndex == teamIndex) return e;
    }
    return null;
  }

  bool isFoodDone(int foodIndex) => entryFor(foodIndex, 0) != null && entryFor(foodIndex, 1) != null;

  int get doneCount => List.generate(foods.length, (i) => i).where(isFoodDone).length;

  /// Erstes Lebensmittel, bei dem noch ein Ergebnis fehlt (null = alle fertig)
  int? get currentFoodIndex {
    for (int i = 0; i < foods.length; i++) {
      if (!isFoodDone(i)) return i;
    }
    return null;
  }

  bool get isComplete => foods.isNotEmpty && currentFoodIndex == null;

  /// Summierte Abweichung in Prozent pro WG (kleiner ist besser)
  List<double> get totals {
    final result = [0.0, 0.0];
    for (final e in entries) {
      if (e.teamIndex == 0 || e.teamIndex == 1) result[e.teamIndex] += e.deviation;
    }
    return result;
  }

  /// WG mit der kleineren Gesamtabweichung, sobald alle Lebensmittel geteilt sind.
  /// null = läuft noch oder Gleichstand.
  int? get winnerIndex {
    if (!isComplete) return null;
    final t = totals;
    if (t[0] < t[1]) return 0;
    if (t[1] < t[0]) return 1;
    return null;
  }

  /// UIDs, die in einem Akt für eine WG schon zerteilt haben
  Set<String> cuttersInAct(int act, int teamIndex) {
    return {
      for (final e in entries)
        if (e.teamIndex == teamIndex && e.foodIndex < foods.length && foods[e.foodIndex].act == act)
          ?e.cutterUid,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'date': Timestamp.fromDate(date),
      'memberUids': memberUids,
      'teams': teams.map((t) => t.toMap()).toList(),
      'foods': foods.map((f) => f.toMap()).toList(),
      'secondsPerFood': secondsPerFood,
      'entries': entries.map((e) => e.toMap()).toList(),
      'status': status,
    };
  }

  factory HalbierenGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return HalbierenGame.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory HalbierenGame.fromMap(Map<String, dynamic> data, {String? id}) {
    final teamsRaw = (data['teams'] as List<dynamic>?) ?? [];
    final foodsRaw = (data['foods'] as List<dynamic>?) ?? [];
    final entriesRaw = (data['entries'] as List<dynamic>?) ?? [];
    return HalbierenGame(
      id: id,
      createdBy: data['createdBy'] ?? '',
      date: data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      memberUids: List<String>.from(data['memberUids'] ?? []),
      teams: teamsRaw.map((t) => HalbierenTeam.fromMap(Map<String, dynamic>.from(t as Map))).toList(),
      foods: foodsRaw.map((f) => TeilenFood.fromMap(Map<String, dynamic>.from(f as Map))).toList(),
      secondsPerFood: (data['secondsPerFood'] as num?)?.toInt() ?? 180,
      entries: entriesRaw.map((e) => TeilenEntry.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      status: data['status'] ?? 'active',
    );
  }
}

// Formatiert Prozentwerte mit Komma, z.B. "4,2 %"
String formatTeilenPercent(double value) => '${value.toStringAsFixed(1).replaceAll('.', ',')} %';
