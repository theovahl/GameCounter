import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final AuthService _authService = AuthService();
  final _searchController = TextEditingController();

  Map<String, dynamic>? _foundUser;
  bool _isSearching = false;
  String? _searchError;

  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundUser = null;
      _searchError = null;
    });

    final result = await _authService.searchUserByTag(query);

    setState(() {
      _isSearching = false;
      if (result == null) {
        _searchError = 'Kein Benutzer mit diesem Tag gefunden.';
      } else if (result['uid'] == _authService.currentUserId) {
        _searchError = 'Das ist dein eigener Tag!';
      } else {
        _foundUser = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freunde & Netzwerke'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _authService.currentUserStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final myData = snapshot.data?.data() ?? {};
          final myUserTag = myData['userTag'] ?? '';
          final List<String> friendUids = List<String>.from(myData['friends'] ?? []);
          final List<String> incomingUids = List<String>.from(myData['incomingRequests'] ?? []);
          final List<String> outgoingUids = List<String>.from(myData['outgoingRequests'] ?? []);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eigener User-Tag Banner
                Card(
                  color: Colors.green.shade900.withValues(alpha: 0.4),
                  child: ListTile(
                    leading: const Icon(Icons.badge, color: Colors.greenAccent),
                    title: const Text('Dein User-Tag'),
                    subtitle: Text(
                      myUserTag,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    trailing: const Tooltip(
                      message: 'Teile diesen Tag mit Freunden',
                      child: Icon(Icons.info_outline),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Freund suchen',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Suchzeile
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'User-Tag eingeben (z. B. Max#1234)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSearching ? null : _performSearch,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),

                if (_searchError != null) ...[
                  const SizedBox(height: 8),
                  Text(_searchError!, style: const TextStyle(color: Colors.redAccent)),
                ],

                // Suchergebnis-Karte
                if (_foundUser != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(_foundUser!['username'] ?? ''),
                      subtitle: Text(_foundUser!['userTag'] ?? ''),
                      trailing: _buildActionButton(
                        targetUid: _foundUser!['uid'],
                        friends: friendUids,
                        incoming: incomingUids,
                        outgoing: outgoingUids,
                      ),
                    ),
                  ),
                ],

                // Ausstehende Anfragen
                if (incomingUids.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Eingehende Anfragen (${incomingUids.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _authService.getUsersByIds(incomingUids),
                    builder: (context, reqSnapshot) {
                      if (!reqSnapshot.hasData) return const SizedBox();
                      return Column(
                        children: reqSnapshot.data!.map((reqUser) {
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person_add)),
                              title: Text(reqUser['username'] ?? ''),
                              subtitle: Text(reqUser['userTag'] ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () => _authService.acceptFriendRequest(reqUser['uid']),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => _authService.rejectFriendRequest(reqUser['uid']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],

                // Liste bestätigter Freunde
                const SizedBox(height: 24),
                Text(
                  'Meine Freunde (${friendUids.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (friendUids.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Noch keine Freunde hinzugefügt. Suche oben nach deinen Mitspielern!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _authService.getUsersByIds(friendUids),
                    builder: (context, friendsSnapshot) {
                      if (!friendsSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: friendsSnapshot.data!.length,
                        itemBuilder: (context, index) {
                          final friend = friendsSnapshot.data![index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.green,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              title: Text(
                                friend['username'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(friend['userTag'] ?? ''),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Hilfsmethode für den passenden Button im Suchergebnis
  Widget _buildActionButton({
    required String targetUid,
    required List<String> friends,
    required List<String> incoming,
    required List<String> outgoing,
  }) {
    if (friends.contains(targetUid)) {
      return const Chip(
        label: Text('Befreundet'),
        avatar: Icon(Icons.check, size: 16),
      );
    }
    if (outgoing.contains(targetUid)) {
      return const Chip(label: Text('Angefragt'));
    }
    if (incoming.contains(targetUid)) {
      return ElevatedButton(
        onPressed: () => _authService.acceptFriendRequest(targetUid),
        child: const Text('Annehmen'),
      );
    }

    return ElevatedButton.icon(
      onPressed: () async {
        await _authService.sendFriendRequest(targetUid);
        setState(() {});
      },
      icon: const Icon(Icons.person_add),
      label: const Text('Hinzufügen'),
    );
  }
}