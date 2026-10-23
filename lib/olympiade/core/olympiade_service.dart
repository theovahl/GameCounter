import 'package:cloud_firestore/cloud_firestore.dart';
import 'olympiade_models.dart';

class OlympiadeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _olympiadenRef =>
      _firestore.collection('olympiade_games');

  /// Legt eine neue WG Olympiade an
  Future<OlympiadeGame> createOlympiade({
    required String editionId,
    required String createdBy,
    required List<OlympiadeWg> wgs,
    required List<String> disciplines,
  }) async {
    final memberUids = <String>{
      createdBy,
      for (final wg in wgs) ...wg.playerUids,
    }.toList();

    final olympiade = OlympiadeGame(
      editionId: editionId,
      createdBy: createdBy,
      date: DateTime.now(),
      memberUids: memberUids,
      wgs: wgs,
      disciplines: disciplines,
      separateGames: true,
    );

    final docRef = await _olympiadenRef.add(olympiade.toMap());
    return OlympiadeGame.fromMap(olympiade.toMap(), id: docRef.id);
  }

  /// Live-Stream einer konkreten Olympiade
  Stream<OlympiadeGame?> getOlympiadeStream(String olympiadeId) {
    return _olympiadenRef.doc(olympiadeId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return OlympiadeGame.fromFirestore(doc);
    });
  }

  /// Stream aller Olympiaden, an denen [currentUserId] beteiligt ist
  Stream<List<OlympiadeGame>> getUserOlympiadenStream(String currentUserId) {
    return _olympiadenRef
        .where('memberUids', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => OlympiadeGame.fromFirestore(doc)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  /// Speichert den Stand einer Disziplin. Sind alle entschieden, wird die Olympiade beendet.
  Future<void> setResult({
    required OlympiadeGame olympiade,
    required String discipline,
    required OlympiadeResult result,
  }) async {
    final updated = olympiade.copyWithResult(discipline, result);
    await _olympiadenRef.doc(olympiade.id).update({
      'results.$discipline': result.toMap(),
      'status': updated.allDone ? 'finished' : 'active',
    });
  }

  /// Beendet die Olympiade manuell
  Future<void> finishOlympiade(String olympiadeId) async {
    await _olympiadenRef.doc(olympiadeId).update({'status': 'finished'});
  }

  /// Löscht eine Olympiade samt ihrer eigenen Spiele. Spiele älterer Olympiaden, die noch
  /// in den normalen Modi liegen, bleiben dort erhalten.
  Future<void> deleteOlympiade(OlympiadeGame olympiade) async {
    final docRef = _olympiadenRef.doc(olympiade.id);
    final disciplines = {...olympiade.disciplines, ...olympiade.edition.disciplineKeys};
    for (final discipline in disciplines) {
      final games = await docRef.collection('${discipline}_games').get();
      if (games.docs.isEmpty) continue;
      final batch = _firestore.batch();
      for (final game in games.docs) {
        batch.delete(game.reference);
      }
      await batch.commit();
    }
    await docRef.delete();
  }
}
