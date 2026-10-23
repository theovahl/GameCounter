import 'package:cloud_firestore/cloud_firestore.dart';
import 'boule_models.dart';

class BouleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Optional eigene Collection für die Spiele (z.B. die einer WG Olympiade),
  // sonst die normale Collection des Modus
  final CollectionReference<Map<String, dynamic>>? _customGamesRef;

  BouleService({CollectionReference<Map<String, dynamic>>? gamesRef}) : _customGamesRef = gamesRef;

  CollectionReference<Map<String, dynamic>> get _gamesRef =>
      _customGamesRef ?? _firestore.collection('boule_games');

  /// Startet ein neues Boule-Spiel mit den angegebenen Teams und Modus
  Future<BouleGame> createGame({
    required String createdBy,
    required List<BouleTeam> teams,
    required int pointsPerSet,
    required int setsToWin,
  }) async {
    final memberUids = <String>{
      createdBy,
      for (final team in teams) ...team.playerUids,
    }.toList();

    final game = BouleGame(
      createdBy: createdBy,
      date: DateTime.now(),
      memberUids: memberUids,
      teams: teams,
      pointsPerSet: pointsPerSet,
      setsToWin: setsToWin,
    );

    final docRef = await _gamesRef.add(game.toMap());
    return BouleGame.fromMap(game.toMap(), id: docRef.id);
  }

  /// Live-Stream eines konkreten Boule-Spiels
  Stream<BouleGame?> getGameStream(String gameId) {
    return _gamesRef.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BouleGame.fromFirestore(doc);
    });
  }

  /// Stream aller Boule-Spiele, an denen [currentUserId] beteiligt ist
  Stream<List<BouleGame>> getUserGamesStream(String currentUserId) {
    return _gamesRef
        .where('memberUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs.map((doc) => BouleGame.fromFirestore(doc)).toList();
      games.sort((a, b) => b.date.compareTo(a.date));
      return games;
    });
  }

  /// Speichert die Aufnahmen. Ist ein Sieger ermittelt, wird das Spiel automatisch beendet.
  Future<void> updateEnds({
    required BouleGame game,
    required List<BouleEnd> ends,
  }) async {
    final updated = BouleGame(
      createdBy: game.createdBy,
      date: game.date,
      memberUids: game.memberUids,
      teams: game.teams,
      pointsPerSet: game.pointsPerSet,
      setsToWin: game.setsToWin,
      ends: ends,
    );

    await _gamesRef.doc(game.id).update({
      'ends': ends.map((e) => e.toMap()).toList(),
      'status': updated.winnerTeam != null ? 'finished' : 'active',
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
