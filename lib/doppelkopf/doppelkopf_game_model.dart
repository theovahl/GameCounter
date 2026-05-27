// Repräsentiert eine einzelne gespielte Runde
class GameRound {
  final int roundNumber;
  final List<int> scores; // Die Punkte für die 4 Spieler, z.B. [3, 3, -3, -3]

  GameRound({required this.roundNumber, required this.scores});
}

// Repräsentiert das gesamte Spiel
class DoppelkopfGame {
  List<String> players; // Die 4 Namen der Spieler
  List<GameRound> rounds = []; // Liste aller bisherigen Runden

  DoppelkopfGame({required this.players});

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