import 'package:cloud_firestore/cloud_firestore.dart';
import 'darts_models.dart';

class DartsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Optional eigene Collection für die Spiele (z.B. die einer WG Olympiade),
  // sonst die normale Collection des Modus
  final CollectionReference<Map<String, dynamic>>? _customGamesRef;

  DartsService({CollectionReference<Map<String, dynamic>>? gamesRef}) : _customGamesRef = gamesRef;

  CollectionReference<Map<String, dynamic>> get _gamesRef =>
      _customGamesRef ?? _firestore.collection('darts_games');

  /// Startet ein neues Dart-Match zwischen zwei Spielern
  Future<DartsGame> createGame({
    required String createdBy,
    required List<String> playerUids,
    required List<String> playerNames,
    required int legsToWin,
  }) async {
    final game = DartsGame(
      createdBy: createdBy,
      date: DateTime.now(),
      playerUids: playerUids,
      playerNames: playerNames,
      legsToWin: legsToWin,
    );

    final docRef = await _gamesRef.add(game.toMap());
    return DartsGame.fromMap(game.toMap(), id: docRef.id);
  }

  /// Live-Stream eines konkreten Dart-Matches
  Stream<DartsGame?> getGameStream(String gameId) {
    return _gamesRef.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DartsGame.fromFirestore(doc);
    });
  }

  /// Stream aller Dart-Matches, an denen [currentUserId] teilnimmt
  Stream<List<DartsGame>> getUserGamesStream(String currentUserId) {
    return _gamesRef
        .where('playerUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs.map((doc) => DartsGame.fromFirestore(doc)).toList();
      games.sort((a, b) => b.date.compareTo(a.date));
      return games;
    });
  }

  /// Speichert die Legs. Hat ein Spieler genug Legs, wird das Match automatisch beendet.
  Future<void> updateLegs({
    required DartsGame game,
    required List<DartsLeg> legs,
  }) async {
    final updated = DartsGame(
      createdBy: game.createdBy,
      date: game.date,
      playerUids: game.playerUids,
      playerNames: game.playerNames,
      legsToWin: game.legsToWin,
      legs: legs,
    );

    await _gamesRef.doc(game.id).update({
      'legs': legs.map((l) => l.toMap()).toList(),
      'status': updated.winnerIndex != null ? 'finished' : 'active',
    });
  }

  /// Beendet das Match manuell
  Future<void> finishGame(String gameId) async {
    await _gamesRef.doc(gameId).update({'status': 'finished'});
  }

  /// Löscht ein Match vollständig aus der Datenbank (verwerfen)
  Future<void> deleteGame(String gameId) async {
    await _gamesRef.doc(gameId).delete();
  }
}
