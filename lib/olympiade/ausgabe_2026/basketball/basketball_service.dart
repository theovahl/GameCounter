import 'package:cloud_firestore/cloud_firestore.dart';
import 'basketball_models.dart';

class BasketballService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Optional eigene Collection für die Spiele (z.B. die einer WG Olympiade),
  // sonst die normale Collection des Modus
  final CollectionReference<Map<String, dynamic>>? _customGamesRef;

  BasketballService({CollectionReference<Map<String, dynamic>>? gamesRef}) : _customGamesRef = gamesRef;

  CollectionReference<Map<String, dynamic>> get _gamesRef =>
      _customGamesRef ?? _firestore.collection('basketball_games');

  /// Startet ein neues Basketball-Spiel mit zwei Teams
  Future<BasketballGame> createGame({
    required String createdBy,
    required List<BasketballTeam> teams,
    required int winsNeeded,
  }) async {
    final memberUids = <String>{
      createdBy,
      for (final team in teams) ...team.playerUids,
    }.toList();

    final game = BasketballGame(
      createdBy: createdBy,
      date: DateTime.now(),
      memberUids: memberUids,
      teams: teams,
      winsNeeded: winsNeeded,
    );

    final docRef = await _gamesRef.add(game.toMap());
    return BasketballGame.fromMap(game.toMap(), id: docRef.id);
  }

  /// Live-Stream eines konkreten Basketball-Spiels
  Stream<BasketballGame?> getGameStream(String gameId) {
    return _gamesRef.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BasketballGame.fromFirestore(doc);
    });
  }

  /// Stream aller Basketball-Spiele, an denen [currentUserId] beteiligt ist
  Stream<List<BasketballGame>> getUserGamesStream(String currentUserId) {
    return _gamesRef
        .where('memberUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs.map((doc) => BasketballGame.fromFirestore(doc)).toList();
      games.sort((a, b) => b.date.compareTo(a.date));
      return games;
    });
  }

  /// Speichert die Partien. Hat ein Team genug Siege, wird das Spiel automatisch beendet.
  Future<void> updateRounds({
    required BasketballGame game,
    required List<BasketballRound> rounds,
  }) async {
    final updated = BasketballGame(
      createdBy: game.createdBy,
      date: game.date,
      memberUids: game.memberUids,
      teams: game.teams,
      winsNeeded: game.winsNeeded,
      rounds: rounds,
    );

    await _gamesRef.doc(game.id).update({
      'rounds': rounds.map((r) => r.toMap()).toList(),
      'status': updated.winnerIndex != null ? 'finished' : 'active',
    });
  }

  /// Beendet das Spiel manuell
  Future<void> finishGame(String gameId) async {
    await _gamesRef.doc(gameId).update({'status': 'finished'});
  }

  /// Löscht ein Spiel vollständig aus der Datenbank (verwerfen)
  Future<void> deleteGame(String gameId) async {
    await _gamesRef.doc(gameId).delete();
  }
}
