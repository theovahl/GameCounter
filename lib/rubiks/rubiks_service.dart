import 'package:cloud_firestore/cloud_firestore.dart';
import 'rubiks_models.dart';

class RubiksService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Optional eigene Collection für die Spiele (z.B. die einer WG Olympiade),
  // sonst die normale Collection des Modus
  final CollectionReference<Map<String, dynamic>>? _customGamesRef;

  RubiksService({CollectionReference<Map<String, dynamic>>? gamesRef}) : _customGamesRef = gamesRef;

  CollectionReference<Map<String, dynamic>> get _gamesRef =>
      _customGamesRef ?? _firestore.collection('rubiks_games');

  /// Startet ein neues Rubik's-Cube-Spiel mit zwei Teams
  Future<RubiksGame> createGame({
    required String createdBy,
    required List<RubiksTeam> teams,
    required int winsNeeded,
  }) async {
    final memberUids = <String>{
      createdBy,
      for (final team in teams) ...team.playerUids,
    }.toList();

    final game = RubiksGame(
      createdBy: createdBy,
      date: DateTime.now(),
      memberUids: memberUids,
      teams: teams,
      winsNeeded: winsNeeded,
    );

    final docRef = await _gamesRef.add(game.toMap());
    return RubiksGame.fromMap(game.toMap(), id: docRef.id);
  }

  /// Live-Stream eines konkreten Rubik's-Cube-Spiels
  Stream<RubiksGame?> getGameStream(String gameId) {
    return _gamesRef.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return RubiksGame.fromFirestore(doc);
    });
  }

  /// Stream aller Rubik's-Cube-Spiele, an denen [currentUserId] beteiligt ist
  Stream<List<RubiksGame>> getUserGamesStream(String currentUserId) {
    return _gamesRef
        .where('memberUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs.map((doc) => RubiksGame.fromFirestore(doc)).toList();
      games.sort((a, b) => b.date.compareTo(a.date));
      return games;
    });
  }

  /// Speichert die Partien. Hat ein Team genug Siege, wird das Spiel automatisch beendet.
  Future<void> updateRounds({
    required RubiksGame game,
    required List<RubiksRound> rounds,
  }) async {
    final updated = RubiksGame(
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
