import 'package:cloud_firestore/cloud_firestore.dart';

// Ein einzelnes Bierpong-Spiel (immer 1 gegen 1) mit Ergebnis
class BierpongGame {
  final String? id; // Firestore Document ID
  final String createdBy;
  final DateTime date;
  final List<String> playerUids; // Genau 2 Spieler
  final List<String> playerNames;
  final int winnerIndex; // 0 oder 1

  BierpongGame({
    this.id,
    required this.createdBy,
    required this.date,
    required this.playerUids,
    required this.playerNames,
    required this.winnerIndex,
  });

  String get winnerUid => playerUids[winnerIndex];
  String get winnerName => playerNames[winnerIndex];

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'date': Timestamp.fromDate(date),
      'playerUids': playerUids,
      'playerNames': playerNames,
      'winnerIndex': winnerIndex,
    };
  }

  factory BierpongGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return BierpongGame.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory BierpongGame.fromMap(Map<String, dynamic> data, {String? id}) {
    return BierpongGame(
      id: id,
      createdBy: data['createdBy'] ?? '',
      date: data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      playerUids: List<String>.from(data['playerUids'] ?? []),
      playerNames: List<String>.from(data['playerNames'] ?? []),
      winnerIndex: (data['winnerIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

// Bilanz eines Spielers gegen einen bestimmten Gegner
class BierpongRecord {
  final String opponentUid;
  final String opponentName;
  int wins = 0;
  int losses = 0;

  BierpongRecord({required this.opponentUid, required this.opponentName});

  int get total => wins + losses;
}

// Berechnet die Bilanz von [myUid] gegen alle Gegner, sortiert nach Anzahl Spiele
List<BierpongRecord> bierpongRecordsFor(String myUid, List<BierpongGame> games) {
  final records = <String, BierpongRecord>{};
  for (final game in games) {
    final myIndex = game.playerUids.indexOf(myUid);
    if (myIndex < 0 || game.playerUids.length != 2) continue;
    final oppIndex = 1 - myIndex;
    final record = records.putIfAbsent(
      game.playerUids[oppIndex],
      () => BierpongRecord(
        opponentUid: game.playerUids[oppIndex],
        opponentName: game.playerNames[oppIndex],
      ),
    );
    if (game.winnerIndex == myIndex) {
      record.wins++;
    } else {
      record.losses++;
    }
  }
  final list = records.values.toList();
  list.sort((a, b) => b.total.compareTo(a.total));
  return list;
}
