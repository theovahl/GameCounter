import 'package:cloud_firestore/cloud_firestore.dart';
import 'geoguessr_models.dart';

class GeoguessrService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Optional eigene Collection für die Spiele (z.B. die einer WG Olympiade),
  // sonst die normale Collection des Modus
  final CollectionReference<Map<String, dynamic>>? _customGamesRef;

  GeoguessrService({CollectionReference<Map<String, dynamic>>? gamesRef}) : _customGamesRef = gamesRef;

  CollectionReference<Map<String, dynamic>> get _gamesRef =>
      _customGamesRef ?? _firestore.collection('geoguessr_games');

  /// Startet ein neues GeoGuessr-Spiel mit zwei Teams
  Future<GeoguessrGame> createGame({
    required String createdBy,
    required List<GeoguessrTeam> teams,
    required List<GeoguessrStage> stages,
  }) async {
    final memberUids = <String>{
      createdBy,
      for (final team in teams) ...team.playerUids,
    }.toList();

    final game = GeoguessrGame(
      createdBy: createdBy,
      date: DateTime.now(),
      memberUids: memberUids,
      teams: teams,
      stages: stages,
    );

    final docRef = await _gamesRef.add(game.toMap());
    return GeoguessrGame.fromMap(game.toMap(), id: docRef.id);
  }

  /// Live-Stream eines konkreten GeoGuessr-Spiels
  Stream<GeoguessrGame?> getGameStream(String gameId) {
    return _gamesRef.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GeoguessrGame.fromFirestore(doc);
    });
  }

  /// Stream aller GeoGuessr-Spiele, an denen [currentUserId] beteiligt ist
  Stream<List<GeoguessrGame>> getUserGamesStream(String currentUserId) {
    return _gamesRef
        .where('memberUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs.map((doc) => GeoguessrGame.fromFirestore(doc)).toList();
      games.sort((a, b) => b.date.compareTo(a.date));
      return games;
    });
  }

  /// Speichert die Runden. Sind alle Stufen entschieden, wird das Spiel automatisch beendet.
  Future<void> updateRounds({
    required GeoguessrGame game,
    required List<GeoguessrRound> rounds,
  }) async {
    final updated = GeoguessrGame(
      createdBy: game.createdBy,
      date: game.date,
      memberUids: game.memberUids,
      teams: game.teams,
      stages: game.stages,
      rounds: rounds,
    );

    await _gamesRef.doc(game.id).update({
      'rounds': rounds.map((r) => r.toMap()).toList(),
      'status': updated.isComplete ? 'finished' : 'active',
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
