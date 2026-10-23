import 'package:cloud_firestore/cloud_firestore.dart';
import 'mariokart_models.dart';
import 'mariokart_data.dart';

class MarioKartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _firestore.collection('mariokart_groups');

  // Optional eigene Collection für die Spiele (z.B. die einer WG Olympiade),
  // sonst die normale Collection des Modus
  final CollectionReference<Map<String, dynamic>>? _customGamesRef;

  MarioKartService({CollectionReference<Map<String, dynamic>>? gamesRef}) : _customGamesRef = gamesRef;

  CollectionReference<Map<String, dynamic>> get _gamesRef =>
      _customGamesRef ?? _firestore.collection('mariokart_games');

  // --- GRUPPEN ---

  /// Erstellt eine neue Mario Kart Gruppe mit beliebiger Spieleranzahl
  Future<MarioKartGroup> createGroup({
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
    return MarioKartGroup(
      id: docRef.id,
      name: name,
      createdBy: createdBy,
      playerUids: playerUids,
      playerNames: playerNames,
      createdAt: now,
    );
  }

  /// Liefert einen Live-Stream aller Gruppen, in denen [currentUserId] mitspielt
  Stream<List<MarioKartGroup>> getGroupsStream(String currentUserId) {
    return _groupsRef
        .where('playerUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final groups = snapshot.docs
          .map((doc) => MarioKartGroup.fromFirestore(doc))
          .toList();
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    });
  }

  /// Einmaliges Laden aller Gruppen des Nutzers
  Future<List<MarioKartGroup>> getGroupsForUser(String currentUserId) async {
    final query = await _groupsRef
        .where('playerUids', arrayContains: currentUserId)
        .get();

    final groups =
        query.docs.map((doc) => MarioKartGroup.fromFirestore(doc)).toList();
    groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return groups;
  }

  // --- GRAND PRIX MATCHES ---

  /// Startet ein neues Grand Prix Spiel für eine Gruppe
  Future<MarioKartGame> createGame({
    required MarioKartGroup group,
    required MarioKartCup cup,
    required String createdBy,
  }) async {
    final now = DateTime.now();
    final initialScores = <String, int>{};
    for (var uid in group.playerUids) {
      initialScores[uid] = 0;
    }

    final initialCup = MarioKartCupInfo(
      cupId: cup.id,
      cupName: cup.name,
      tracks: cup.tracks,
    );

    final gameData = {
      'groupId': group.id ?? '',
      'groupName': group.name,
      'cups': [initialCup.toMap()],
      'cupId': cup.id,
      'cupName': cup.name,
      'cupTracks': cup.tracks,
      'createdBy': createdBy,
      'date': Timestamp.fromDate(now),
      'playerUids': group.playerUids,
      'playerNames': group.playerNames,
      'races': <Map<String, dynamic>>[],
      'totalScores': initialScores,
      'status': 'active',
    };

    final docRef = await _gamesRef.add(gameData);
    return MarioKartGame(
      id: docRef.id,
      groupId: group.id ?? '',
      groupName: group.name,
      cups: [initialCup],
      createdBy: createdBy,
      date: now,
      playerUids: group.playerUids,
      playerNames: group.playerNames,
      races: [],
      totalScores: initialScores,
      status: 'active',
    );
  }

  /// Fügt einen weiteren Cup zum laufenden Match hinzu
  Future<void> addNextCup({
    required String gameId,
    required MarioKartCup nextCup,
    required List<MarioKartCupInfo> currentCups,
  }) async {
    final updatedCups = List<MarioKartCupInfo>.from(currentCups)
      ..add(MarioKartCupInfo(
        cupId: nextCup.id,
        cupName: nextCup.name,
        tracks: nextCup.tracks,
      ));

    await _gamesRef.doc(gameId).update({
      'cups': updatedCups.map((c) => c.toMap()).toList(),
      'cupId': nextCup.id,
      'cupName': nextCup.name,
      'cupTracks': nextCup.tracks,
    });
  }

  /// Fügt eine einzelne Strecke hinzu. Ist der aktuelle Abschnitt bereits eine eigene
  /// Streckenauswahl, wird die Strecke dort angehängt, sonst entsteht ein neuer Abschnitt.
  Future<void> addSingleTrack({
    required String gameId,
    required String track,
    required List<MarioKartCupInfo> currentCups,
  }) async {
    final updatedCups = List<MarioKartCupInfo>.from(currentCups);
    if (updatedCups.isNotEmpty && updatedCups.last.cupId == MarioKartData.customCupId) {
      final last = updatedCups.removeLast();
      updatedCups.add(MarioKartCupInfo(
        cupId: last.cupId,
        cupName: last.cupName,
        tracks: [...last.tracks, track],
      ));
    } else {
      updatedCups.add(MarioKartCupInfo(
        cupId: MarioKartData.customCupId,
        cupName: 'Einzelne Strecken',
        tracks: [track],
      ));
    }

    final active = updatedCups.last;
    await _gamesRef.doc(gameId).update({
      'cups': updatedCups.map((c) => c.toMap()).toList(),
      'cupId': active.cupId,
      'cupName': active.cupName,
      'cupTracks': active.tracks,
    });
  }

  /// Live-Stream eines konkreten Mario Kart Matches
  Stream<MarioKartGame?> getGameStream(String gameId) {
    return _gamesRef.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MarioKartGame.fromFirestore(doc);
    });
  }

  /// Stream aller Mario Kart Spiele, an denen [currentUserId] teilnimmt
  Stream<List<MarioKartGame>> getUserGamesStream(String currentUserId) {
    return _gamesRef
        .where('playerUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs
          .map((doc) => MarioKartGame.fromFirestore(doc))
          .toList();
      games.sort((a, b) => b.date.compareTo(a.date));
      return games;
    });
  }

  /// Stream aller Spiele einer bestimmten Gruppe, chronologisch aufsteigend sortiert (für Verlaufsanalysen)
  Stream<List<MarioKartGame>> getGamesForGroupStream(String groupId) {
    return _gamesRef
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
      final games = snapshot.docs
          .map((doc) => MarioKartGame.fromFirestore(doc))
          .toList();
      games.sort((a, b) => a.date.compareTo(b.date));
      return games;
    });
  }

  /// Aktualisiert die gefahrenen Strecken und die Gesamtpunkte
  Future<void> updateRacesAndTotals({
    required String gameId,
    required List<MarioKartRace> races,
    required Map<String, int> totalScores,
  }) async {
    await _gamesRef.doc(gameId).update({
      'races': races.map((r) => r.toMap()).toList(),
      'totalScores': totalScores,
    });
  }

  /// Beendet das Grand Prix Spiel (optional mit Multiplikatoren)
  Future<void> finishGame(
    String gameId, {
    bool hasMultipliers = false,
    Map<String, double>? appliedMultipliers,
    Map<String, double>? modifiedTotalScores,
  }) async {
    final updateData = <String, dynamic>{
      'status': 'finished',
      'hasMultipliers': hasMultipliers,
    };
    if (appliedMultipliers != null) {
      updateData['appliedMultipliers'] = appliedMultipliers;
    }
    if (modifiedTotalScores != null) {
      updateData['modifiedTotalScores'] = modifiedTotalScores;
    }
    await _gamesRef.doc(gameId).update(updateData);
  }

  /// Löscht ein Match vollständig aus der Datenbank (verwerfen)
  Future<void> deleteGame(String gameId) async {
    await _gamesRef.doc(gameId).delete();
  }
}

