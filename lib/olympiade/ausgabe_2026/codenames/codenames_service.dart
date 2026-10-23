import 'package:cloud_firestore/cloud_firestore.dart';
import 'codenames_models.dart';

class CodenamesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Optional eigene Collection für die Spiele (z.B. die einer WG Olympiade),
  // sonst die normale Collection des Modus
  final CollectionReference<Map<String, dynamic>>? _customGamesRef;

  CodenamesService({CollectionReference<Map<String, dynamic>>? gamesRef}) : _customGamesRef = gamesRef;

  CollectionReference<Map<String, dynamic>> get _gamesRef =>
      _customGamesRef ?? _firestore.collection('codenames_games');

  /// Startet ein neues Codenames-Match mit zwei Teams
  Future<CodenamesGame> createGame({
    required String createdBy,
    required List<CodenamesTeam> teams,
    required int winsNeeded,
  }) async {
    final memberUids = <String>{
      createdBy,
      for (final team in teams) ...team.playerUids,
    }.toList();

    final game = CodenamesGame(
      createdBy: createdBy,
      date: DateTime.now(),
      memberUids: memberUids,
      teams: teams,
      winsNeeded: winsNeeded,
    );

    final docRef = await _gamesRef.add(game.toMap());
    return CodenamesGame.fromMap(game.toMap(), id: docRef.id);
  }

  /// Live-Stream eines konkreten Codenames-Matches
  Stream<CodenamesGame?> getGameStream(String gameId) {
    return _gamesRef.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CodenamesGame.fromFirestore(doc);
    });
  }

  /// Stream aller Codenames-Matches, an denen [currentUserId] beteiligt ist
  Stream<List<CodenamesGame>> getUserGamesStream(String currentUserId) {
    return _gamesRef
        .where('memberUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs.map((doc) => CodenamesGame.fromFirestore(doc)).toList();
      games.sort((a, b) => b.date.compareTo(a.date));
      return games;
    });
  }

  /// Speichert die Partien. Hat ein Team genug Siege, wird das Match automatisch beendet.
  Future<void> updateRounds({
    required CodenamesGame game,
    required List<CodenamesRound> rounds,
  }) async {
    final updated = CodenamesGame(
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

  /// Beendet das Match manuell
  Future<void> finishGame(String gameId) async {
    await _gamesRef.doc(gameId).update({'status': 'finished'});
  }

  /// Löscht ein Match vollständig aus der Datenbank (verwerfen)
  Future<void> deleteGame(String gameId) async {
    await _gamesRef.doc(gameId).delete();
  }
}
