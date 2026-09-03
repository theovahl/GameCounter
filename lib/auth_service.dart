import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Aktueller Benutzer als Stream (ändert sich automatisch bei Login/Logout)
  Stream<User?> get userStream => _auth.authStateChanges();

  // Aktuelle User-ID abrufen
  String? get currentUserId => _auth.currentUser?.uid;

  // Registrierung mit E-Mail, Passwort und Anzeigenamen
  Future<String?> registerWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // 1. Account in Firebase Auth erstellen
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // 2. Einzigartigen 4-stelligen Tag generieren (z. B. 4821)
        String tag = (1000 + Random().nextInt(9000)).toString();
        String userTag = '$username#$tag';

        // 3. Profil in Firestore-Datenbank anlegen
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'username': username,
          'userTag': userTag, // z. B. "Max#4821"
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'friends': [], // Liste der Freunde-UIDs
        });
      }
      return null; // Kein Fehler
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Ein unerwarteter Fehler ist aufgetreten.';
    }
  }

  // Login mit E-Mail und Passwort
  Future<String?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // Erfolg
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Anmeldung fehlgeschlagen.';
    }
  }

  // Abmelden
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Live-Stream des eigenen Benutzer-Dokuments
  Stream<DocumentSnapshot<Map<String, dynamic>>> get currentUserStream {
    final uid = currentUserId;
    if (uid == null) throw Exception('Kein Nutzer eingeloggt');
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // Nutzer über exakten User-Tag (z.B. "Max#4821") suchen
  Future<Map<String, dynamic>?> searchUserByTag(String tag) async {
    final query = await _firestore
        .collection('users')
        .where('userTag', isEqualTo: tag.trim())
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.data();
    }
    return null;
  }

  // Freundschaftsanfrage senden
  Future<String?> sendFriendRequest(String targetUid) async {
    final myUid = currentUserId;
    if (myUid == null || myUid == targetUid) return 'Ungültige Anfrage.';

    try {
      // Füge targetUid bei eigenen 'outgoingRequests' hinzu
      await _firestore.collection('users').doc(myUid).update({
        'outgoingRequests': FieldValue.arrayUnion([targetUid]),
      });

      // Füge myUid bei den 'incomingRequests' des Zielnutzers hinzu
      await _firestore.collection('users').doc(targetUid).update({
        'incomingRequests': FieldValue.arrayUnion([myUid]),
      });

      return null; // Erfolg
    } catch (e) {
      return 'Fehler beim Senden der Anfrage.';
    }
  }

  // Freundschaftsanfrage annehmen
  Future<void> acceptFriendRequest(String requesterUid) async {
    final myUid = currentUserId;
    if (myUid == null) return;

    final batch = _firestore.batch();

    // Bei mir: Anfrage entfernen, Freund hinzufügen
    batch.update(_firestore.collection('users').doc(myUid), {
      'incomingRequests': FieldValue.arrayRemove([requesterUid]),
      'friends': FieldValue.arrayUnion([requesterUid]),
    });

    // Beim Gegenüber: Ausgehende Anfrage entfernen, Freund hinzufügen
    batch.update(_firestore.collection('users').doc(requesterUid), {
      'outgoingRequests': FieldValue.arrayRemove([myUid]),
      'friends': FieldValue.arrayUnion([myUid]),
    });

    await batch.commit();
  }

  // Freundschaftsanfrage ablehnen
  Future<void> rejectFriendRequest(String requesterUid) async {
    final myUid = currentUserId;
    if (myUid == null) return;

    await _firestore.collection('users').doc(myUid).update({
      'incomingRequests': FieldValue.arrayRemove([requesterUid]),
    });

    await _firestore.collection('users').doc(requesterUid).update({
      'outgoingRequests': FieldValue.arrayRemove([myUid]),
    });
  }

  // Profil-Daten für eine Liste von UIDs abrufen
  Future<List<Map<String, dynamic>>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];

    final snapshots = await Future.wait(
      uids.map((uid) => _firestore.collection('users').doc(uid).get()),
    );

    return snapshots
        .where((doc) => doc.exists)
        .map((doc) => doc.data()!)
        .toList();
  }
}