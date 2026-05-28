class PlayerGroup {
  final int? id; // Wird von der Datenbank automatisch vergeben
  final String name;
  final List<String> players; // Die 4 festen Namen dieser Gruppe

  PlayerGroup({this.id, required this.name, required this.players});

  // Hilfsfunktionen, um Daten in die DB zu schreiben und zu lesen
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'players': players.join(','), // Speichert ['A','B','C','D'] als "A,B,C,D"
    };
  }

  factory PlayerGroup.fromMap(Map<String, dynamic> map) {
    return PlayerGroup(
      id: map['id'],
      name: map['name'],
      players: (map['players'] as String).split(','),
    );
  }
}

// Repräsentiert eine einzelne gespielte Runde
class GameRound {
  final int? id;
  final int gameId;
  final int roundNumber;
  final List<int> scores; // Die Punkte für die 4 Spieler, z.B. [3, 3, -3, -3]

  GameRound({this.id, required this.gameId, required this.roundNumber, required this.scores});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameId': gameId,
      'roundNumber': roundNumber,
      'scores': scores.join(','), // Speichert [3,3,-3,-3] als "3,3,-3,-3"
    };
  }
}

// Repräsentiert das gesamte Spiel
class DoppelkopfGame {
  final int? id;
  final int groupId; // Verknüpfung: Zu welcher Gruppe gehört dieses Spiel?
  final DateTime date;
  List<String> players; // Die 4 Namen der Spieler
  List<GameRound> rounds = []; // Liste aller bisherigen Runden

  DoppelkopfGame({this.id, required this.groupId, required this.date, required this.players});

  // Berechnet live die aktuellen Gesamtpunkte aller Spieler
  List<int> get totalScores {
    List<int> totals = [0, 0, 0, 0];
    for (var round in rounds) {
      for (int i = 0; i < 4; i++) {
        totals[i] += round.scores[i];
      }
    }
    return totals;
  }
}