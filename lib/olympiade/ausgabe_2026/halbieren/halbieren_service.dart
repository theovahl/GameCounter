import 'package:cloud_firestore/cloud_firestore.dart';
import 'halbieren_models.dart';

class HalbierenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Optional eigene Collection für die Spiele (z.B. die einer WG Olympiade),
  // sonst die normale Collection des Modus
  final CollectionReference<Map<String, dynamic>>? _customGamesRef;

  HalbierenService({CollectionReference<Map<String, dynamic>>? gamesRef}) : _customGamesRef = gamesRef;

  CollectionReference<Map<String, dynamic>> get _gamesRef =>
      _customGamesRef ?? _firestore.collection('halbieren_games');

  /// Startet ein neues Spiel "Das Große Teilen" mit zwei Teams und festem Ablauf
  Future<HalbierenGame> createGame({
    required String createdBy,
    required List<HalbierenTeam> teams,
    required List<TeilenFood> foods,
    int secondsPerFood = 180,
  }) async {
    final memberUids = <String>{
      createdBy,
      for (final team in teams) ...team.playerUids,
    }.toList();

    final game = HalbierenGame(
      createdBy: createdBy,
      date: DateTime.now(),
      memberUids: memberUids,
      teams: teams,
      foods: foods,
      secondsPerFood: secondsPerFood,
    );

    final docRef = await _gamesRef.add(game.toMap());
    return HalbierenGame.fromMap(game.toMap(), id: docRef.id);
  }

  /// Live-Stream eines konkreten Spiels
  Stream<HalbierenGame?> getGameStream(String gameId) {
    return _gamesRef.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return HalbierenGame.fromFirestore(doc);
    });
  }

  /// Stream aller Spiele, an denen [currentUserId] beteiligt ist
  Stream<List<HalbierenGame>> getUserGamesStream(String currentUserId) {
    return _gamesRef
        .where('memberUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs.map((doc) => HalbierenGame.fromFirestore(doc)).toList();
      games.sort((a, b) => b.date.compareTo(a.date));
      return games;
    });
  }

  /// Speichert die Ergebnisse. Sind alle Lebensmittel geteilt, wird das Spiel beendet.
  Future<void> updateEntries({
    required HalbierenGame game,
    required List<TeilenEntry> entries,
  }) async {
    final updated = HalbierenGame(
      createdBy: game.createdBy,
      date: game.date,
      memberUids: game.memberUids,
      teams: game.teams,
      foods: game.foods,
      secondsPerFood: game.secondsPerFood,
      entries: entries,
    );

    await _gamesRef.doc(game.id).update({
      'entries': entries.map((e) => e.toMap()).toList(),
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
