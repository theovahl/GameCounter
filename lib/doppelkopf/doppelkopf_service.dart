import 'package:cloud_firestore/cloud_firestore.dart';
import 'doppelkopf_game_model.dart';

class DoppelkopfService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection-Referenzen
  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _firestore.collection('doppelkopf_groups');

  CollectionReference<Map<String, dynamic>> get _gamesRef =>
      _firestore.collection('doppelkopf_games');

  // --- GRUPPEN ---

  /// Erstellt eine neue Doppelkopf-Gruppe in Firestore.
  /// [playerUids] enthält die 4 UIDs aller Mitspieler.
  /// [playerNames] enthält die passenden 4 Spielernamen in Sitzreihenfolge.
  Future<PlayerGroup> createGroup({
    required String name,
    required String createdBy,
    required List<String> playerUids,
    required List<String> playerNames,
  }) async {
    final now = DateTime.now();
    final groupData = {
      'name': name,
      'createdBy': createdBy,
      'playerUids': playerUids,
      'playerNames': playerNames,
      'createdAt': Timestamp.fromDate(now),
    };

    final docRef = await _groupsRef.add(groupData);
    return PlayerGroup(
      id: docRef.id,
      name: name,
      createdBy: createdBy,
      playerUids: playerUids,
      playerNames: playerNames,
      createdAt: now,
    );
  }

  /// Liefert einen Stream aller Gruppen, in denen [currentUserId] mitspielt
  Stream<List<PlayerGroup>> getGroupsStream(String currentUserId) {
    return _groupsRef
        .where('playerUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final groups = snapshot.docs
          .map((doc) => PlayerGroup.fromFirestore(doc))
          .toList();
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    });
  }

  /// Einmaliges Laden aller Gruppen des Nutzers
  Future<List<PlayerGroup>> getGroupsForUser(String currentUserId) async {
    final query = await _groupsRef
        .where('playerUids', arrayContains: currentUserId)
        .get();

    final groups =
        query.docs.map((doc) => PlayerGroup.fromFirestore(doc)).toList();
    groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return groups;
  }

  // --- SPIELE ---

  /// Erstellt ein neues Spiel für eine Gruppe und speichert es in Firestore.
  /// Alle Teilnehmer in [group.playerUids] haben dadurch Zugriff darauf.
  Future<DoppelkopfGame> createGame({
    required PlayerGroup group,
    required String createdBy,
  }) async {
    final now = DateTime.now();
    final initialTotals = [0, 0, 0, 0];

    final gameData = {
      'groupId': group.id ?? '',
      'groupName': group.name,
      'createdBy': createdBy,
      'date': Timestamp.fromDate(now),
      'playerUids': group.playerUids,
      'playerNames': group.playerNames,
      'rounds': <Map<String, dynamic>>[],
      'totalScores': initialTotals,
      'status': 'active',
    };

    final docRef = await _gamesRef.add(gameData);
    return DoppelkopfGame(
      id: docRef.id,
      groupId: group.id ?? '',
      groupName: group.name,
      createdBy: createdBy,
      date: now,
      playerUids: group.playerUids,
      playerNames: group.playerNames,
      rounds: [],
      totalScores: initialTotals,
      status: 'active',
    );
  }

  /// Live-Stream eines konkreten Spiels für Echtzeit-Synchronisation
  Stream<DoppelkopfGame?> getGameStream(String gameId) {
    return _gamesRef.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DoppelkopfGame.fromFirestore(doc);
    });
  }

  /// Stream aller Spiele, an denen [currentUserId] teilnimmt
  Stream<List<DoppelkopfGame>> getUserGamesStream(String currentUserId) {
    return _gamesRef
        .where('playerUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs
          .map((doc) => DoppelkopfGame.fromFirestore(doc))
          .toList();
      games.sort((a, b) => b.date.compareTo(a.date));
      return games;
    });
  }

  /// Fügt eine neue Runde zum Spiel hinzu und aktualisiert die Gesamtpunktzahl.
  Future<void> addRound({
    required String gameId,
    required GameRound round,
    required List<int> newTotalScores,
  }) async {
    await _gamesRef.doc(gameId).update({
      'rounds': FieldValue.arrayUnion([round.toMap()]),
      'totalScores': newTotalScores,
    });
  }

  /// Aktualisiert die gesamte Rundenliste und Gesamtpunktzahl (z.B. nach Bearbeiten oder Löschen)
  Future<void> updateRounds({
    required String gameId,
    required List<GameRound> rounds,
    required List<int> totalScores,
  }) async {
    await _gamesRef.doc(gameId).update({
      'rounds': rounds.map((r) => r.toMap()).toList(),
      'totalScores': totalScores,
    });
  }

  /// Markiert ein Spiel als beendet
  Future<void> finishGame(String gameId) async {
    await _gamesRef.doc(gameId).update({
      'status': 'finished',
    });
  }

  /// Löscht ein Spiel vollständig aus der Datenbank (verwerfen)
  Future<void> deleteGame(String gameId) async {
    await _gamesRef.doc(gameId).delete();
  }
}

