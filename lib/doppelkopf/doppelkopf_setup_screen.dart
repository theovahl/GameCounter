import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_counter/auth_service.dart';
import 'package:game_counter/friends_screen.dart';
import 'doppelkopf_game_model.dart';
import 'doppelkopf_service.dart';
import 'doppelkopf_score_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

enum _SetupTab { games, existingGroup, newGroup }

class _SetupScreenState extends State<SetupScreen> {
  final AuthService _authService = AuthService();
  final DoppelkopfService _doppelkopfService = DoppelkopfService();

  final TextEditingController _groupNameController = TextEditingController();

  _SetupTab _selectedTab = _SetupTab.newGroup;

  String? _selectedGroupId;

  // Ausgewählte Freunde für die 3 Plätze (neben dem Ersteller selbst)
  String? _friend1Uid;
  String? _friend2Uid;
  String? _friend3Uid;

  bool _isStarting = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  void _startNewGameWithNewGroup({
    required String myUid,
    required String myUsername,
    required List<Map<String, dynamic>> friends,
  }) async {
    if (_friend1Uid == null || _friend2Uid == null || _friend3Uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wähle für alle 3 Plätze einen Freund aus.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final selectedUids = {_friend1Uid, _friend2Uid, _friend3Uid};
    if (selectedUids.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wähle 3 unterschiedliche Freunde aus.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isStarting = true);

    try {
      String groupName = _groupNameController.text.trim();
      if (groupName.isEmpty) {
        groupName = 'Runde vom ${DateTime.now().day}.${DateTime.now().month}.';
      }

      String getName(String uid) {
        final friend = friends.firstWhere(
          (f) => f['uid'] == uid,
          orElse: () => {'username': 'Mitspieler'},
        );
        return friend['username'] ?? 'Mitspieler';
      }

      final playerUids = [myUid, _friend1Uid!, _friend2Uid!, _friend3Uid!];
      final playerNames = [
        myUsername,
        getName(_friend1Uid!),
        getName(_friend2Uid!),
        getName(_friend3Uid!),
      ];

      // 1. Neue Gruppe in Firestore anlegen
      final group = await _doppelkopfService.createGroup(
        name: groupName,
        createdBy: myUid,
        playerUids: playerUids,
        playerNames: playerNames,
      );

      // 2. Spiel in Firestore registrieren
      final game = await _doppelkopfService.createGame(
        group: group,
        createdBy: myUid,
      );

      if (!mounted) return;
      setState(() => _isStarting = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ScoreScreen(game: game)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Starten des Spiels: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _startNewGameWithExistingGroup(String myUid) async {
    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wähle eine Gruppe aus.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isStarting = true);

    try {
      final groups = await _doppelkopfService.getGroupsForUser(myUid);
      final group = groups.firstWhere(
        (g) => g.id == _selectedGroupId,
        orElse: () => groups.first,
      );

      final game = await _doppelkopfService.createGame(
        group: group,
        createdBy: myUid,
      );

      if (!mounted) return;
      setState(() => _isStarting = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ScoreScreen(game: game)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Starten des Spiels: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUserId;

    if (myUid == null) {
      return const Scaffold(
        body: Center(child: Text('Bitte melde dich zuerst an.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _authService.currentUserStream,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final myData = userSnapshot.data?.data() ?? {};
        final String myUsername = myData['username'] ?? 'Ich';
        final List<String> friendUids =
            List<String>.from(myData['friends'] ?? []);

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _authService.getUsersByIds(friendUids),
          builder: (context, friendsSnapshot) {
            final friends = friendsSnapshot.data ?? [];

            return Scaffold(
              appBar: AppBar(
                title: const Text('Doppelkopf Setup'),
                centerTitle: true,
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Navigation Tabs
                    SegmentedButton<_SetupTab>(
                      segments: const [
                        ButtonSegment(
                          value: _SetupTab.games,
                          label: Text('Spiele'),
                          icon: Icon(Icons.history),
                        ),
                        ButtonSegment(
                          value: _SetupTab.existingGroup,
                          label: Text('Gruppe'),
                          icon: Icon(Icons.group),
                        ),
                        ButtonSegment(
                          value: _SetupTab.newGroup,
                          label: Text('Neu'),
                          icon: Icon(Icons.group_add),
                        ),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (Set<_SetupTab> newSelection) {
                        setState(() {
                          _selectedTab = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Hauptinhalt je nach gewähltem Tab
                    Expanded(
                      child: _buildTabContent(
                        myUid: myUid,
                        myUsername: myUsername,
                        friends: friends,
                        isLoadingFriends:
                            friendsSnapshot.connectionState ==
                                ConnectionState.waiting,
                      ),
                    ),

                    if (_selectedTab != _SetupTab.games) ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isStarting
                            ? null
                            : () {
                                if (_selectedTab == _SetupTab.newGroup) {
                                  _startNewGameWithNewGroup(
                                    myUid: myUid,
                                    myUsername: myUsername,
                                    friends: friends,
                                  );
                                } else {
                                  _startNewGameWithExistingGroup(myUid);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                        ),
                        child: _isStarting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _selectedTab == _SetupTab.newGroup
                                    ? 'Gruppe erstellen & Spiel starten'
                                    : 'Neues Spiel starten',
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabContent({
    required String myUid,
    required String myUsername,
    required List<Map<String, dynamic>> friends,
    required bool isLoadingFriends,
  }) {
    switch (_selectedTab) {
      case _SetupTab.games:
        return _buildGamesList(myUid);
      case _SetupTab.existingGroup:
        return _buildExistingGroupsView(myUid);
      case _SetupTab.newGroup:
        return _buildNewGroupForm(
          myUid: myUid,
          myUsername: myUsername,
          friends: friends,
          isLoadingFriends: isLoadingFriends,
        );
    }
  }

  void _confirmDeleteGame(DoppelkopfGame game) async {
    final bool isFinished = game.status == 'finished';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFinished ? 'Spiel löschen?' : 'Spiel verwerfen?'),
        content: Text(
          isFinished
              ? 'Möchtest du dieses Spiel aus der Historie entfernen?'
              : 'Möchtest du dieses laufende Spiel wirklich abbrechen und verwerfen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isFinished ? 'Löschen' : 'Verwerfen',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && game.id != null) {
      await _doppelkopfService.deleteGame(game.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFinished ? 'Spiel gelöscht.' : 'Spiel verworfen.',
            ),
          ),
        );
      }
    }
  }

  void _finishGameFromList(DoppelkopfGame game) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spiel beenden?'),
        content: const Text(
          'Möchtest du dieses Spiel wirklich abschließen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Beenden', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true && game.id != null) {
      await _doppelkopfService.finishGame(game.id!);
    }
  }

  // --- TAB 1: Eigene Spiele / Historie ---
  Widget _buildGamesList(String myUid) {
    return StreamBuilder<List<DoppelkopfGame>>(
      stream: _doppelkopfService.getUserGamesStream(myUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final games = snapshot.data ?? [];
        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.style_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Noch keine Doppelkopf-Spiele.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedTab = _SetupTab.newGroup);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Jetzt erstes Spiel starten'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            final bool isActive = game.status == 'active';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isActive ? Colors.white : Colors.grey.shade800,
                  child: const Icon(Icons.style, color: Colors.white, size: 20),
                ),
                title: Text(
                  game.groupName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spieler: ${game.playerNames.join(', ')}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${game.rounds.length} Runden gespielt  |  ${isActive ? "Laufend" : "Abgeschlossen"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? Colors.white : Colors.grey,
                      ),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'open') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScoreScreen(game: game),
                        ),
                      );
                    } else if (value == 'finish') {
                      _finishGameFromList(game);
                    } else if (value == 'delete') {
                      _confirmDeleteGame(game);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(isActive ? Icons.play_arrow : Icons.visibility, size: 18),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Weiterspielen' : 'Ansehen'),
                        ],
                      ),
                    ),
                    if (isActive)
                      const PopupMenuItem(
                        value: 'finish',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Beenden'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_forever, size: 18, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Text(
                            isActive ? 'Verwerfen' : 'Löschen',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScoreScreen(game: game),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: Bestehende Gruppen ---
  Widget _buildExistingGroupsView(String myUid) {
    return StreamBuilder<List<PlayerGroup>>(
      stream: _doppelkopfService.getGroupsStream(myUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data ?? [];
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_off, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Du bist noch in keiner Doppelkopf-Gruppe.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedTab = _SetupTab.newGroup);
                  },
                  icon: const Icon(Icons.group_add),
                  label: const Text('Neue Gruppe mit Freunden anlegen'),
                ),
              ],
            ),
          );
        }

        if (_selectedGroupId == null ||
            !groups.any((g) => g.id == _selectedGroupId)) {
          _selectedGroupId = groups.first.id;
        }

        final selectedGroup = groups.firstWhere(
          (g) => g.id == _selectedGroupId,
          orElse: () => groups.first,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Wähle eine deiner Gruppen für dieses Match:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedGroupId),
              initialValue: _selectedGroupId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              items: groups.map((group) {
                return DropdownMenuItem<String>(
                  value: group.id,
                  child: Text(
                    group.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGroupId = value;
                });
              },
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.grey.shade900,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mitspieler dieser Gruppe:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(selectedGroup.players.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.white,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              selectedGroup.players[i],
                              style: const TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- TAB 3: Neue Gruppe erstellen mit Freunden ---
  Widget _buildNewGroupForm({
    required String myUid,
    required String myUsername,
    required List<Map<String, dynamic>> friends,
    required bool isLoadingFriends,
  }) {
    if (isLoadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }

    if (friends.length < 3) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline,
                  size: 64, color: Colors.amberAccent),
              const SizedBox(height: 16),
              const Text(
                'Zu wenige Freunde für Doppelkopf',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Für ein Doppelkopf-Spiel werden 4 Spieler benötigt (du und 3 Freunde). '
                'Du hast aktuell ${friends.length} Freund(e) in deiner Liste.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FriendsScreen()),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Freunde suchen & hinzufügen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _groupNameController,
            decoration: const InputDecoration(
              labelText: 'Name der Gruppe (z.B. Stammtisch oder Mittwochsrunde)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Spieleraufstellung (4 Spieler):',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Spieler 1 (Festgelegt auf den aktuellen Benutzer)
          Card(
            color: Colors.grey.shade800.withValues(alpha: 0.35),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                '$myUsername (Du)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Spieler 1 • Spielleiter'),
              trailing: const Icon(Icons.lock, size: 18, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 10),

          // Spieler 2 (Freund)
          _buildFriendDropdown(
            label: 'Spieler 2 (Freund auswählen)',
            selectedUid: _friend1Uid,
            friends: friends,
            onChanged: (val) => setState(() => _friend1Uid = val),
          ),
          const SizedBox(height: 10),

          // Spieler 3 (Freund)
          _buildFriendDropdown(
            label: 'Spieler 3 (Freund auswählen)',
            selectedUid: _friend2Uid,
            friends: friends,
            onChanged: (val) => setState(() => _friend2Uid = val),
          ),
          const SizedBox(height: 10),

          // Spieler 4 (Freund)
          _buildFriendDropdown(
            label: 'Spieler 4 (Freund auswählen)',
            selectedUid: _friend3Uid,
            friends: friends,
            onChanged: (val) => setState(() => _friend3Uid = val),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendDropdown({
    required String label,
    required String? selectedUid,
    required List<Map<String, dynamic>> friends,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: selectedUid,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.person_outline),
      ),
      items: friends.map((f) {
        final username = f['username'] ?? 'Unbekannt';
        final userTag = f['userTag'] ?? '';
        return DropdownMenuItem<String>(
          value: f['uid'] as String?,
          child: Text('$username ($userTag)'),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}