import 'package:cloud_firestore/cloud_firestore.dart';
import 'bierpong_models.dart';

class BierpongService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Optional eigene Collection für die Spiele (z.B. die einer WG Olympiade),
  // sonst die normale Collection des Modus
  final CollectionReference<Map<String, dynamic>>? _customGamesRef;

  BierpongService({CollectionReference<Map<String, dynamic>>? gamesRef}) : _customGamesRef = gamesRef;

  CollectionReference<Map<String, dynamic>> get _gamesRef =>
      _customGamesRef ?? _firestore.collection('bierpong_games');

  /// Speichert ein gespieltes Bierpong-Spiel mit Gewinner und gibt dessen ID zurück
  Future<String> saveGame({
    required String createdBy,
    required List<String> playerUids,
    required List<String> playerNames,
    required int winnerIndex,
  }) async {
    final game = BierpongGame(
      createdBy: createdBy,
      date: DateTime.now(),
      playerUids: playerUids,
      playerNames: playerNames,
      winnerIndex: winnerIndex,
    );
    final docRef = await _gamesRef.add(game.toMap());
    return docRef.id;
  }

  /// Live-Stream eines einzelnen Bierpong-Spiels (null = gelöscht)
  Stream<BierpongGame?> getGameStream(String gameId) {
    return _gamesRef.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BierpongGame.fromFirestore(doc);
    });
  }

  /// Lädt ein einzelnes Bierpong-Spiel (null = gelöscht)
  Future<BierpongGame?> getGame(String gameId) async {
    final doc = await _gamesRef.doc(gameId).get();
    if (!doc.exists) return null;
    return BierpongGame.fromFirestore(doc);
  }

  /// Stream aller Bierpong-Spiele, an denen [currentUserId] teilnimmt
  Stream<List<BierpongGame>> getUserGamesStream(String currentUserId) {
    return _gamesRef
        .where('playerUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs.map((doc) => BierpongGame.fromFirestore(doc)).toList();
      games.sort((a, b) => b.date.compareTo(a.date));
      return games;
    });
  }

  /// Löscht ein Spiel (z.B. bei falsch eingetragenem Gewinner)
  Future<void> deleteGame(String gameId) async {
    await _gamesRef.doc(gameId).delete();
  }
}
