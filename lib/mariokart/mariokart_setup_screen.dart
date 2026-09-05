import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_counter/auth_service.dart';
import 'package:game_counter/friends_screen.dart';
import 'mariokart_models.dart';
import 'mariokart_data.dart';
import 'mariokart_service.dart';
import 'mariokart_score_screen.dart';
import 'mariokart_group_stats_screen.dart';

class MarioKartSetupScreen extends StatefulWidget {
  const MarioKartSetupScreen({super.key});

  @override
  State<MarioKartSetupScreen> createState() => _MarioKartSetupScreenState();
}

enum _SetupTab { games, existingGroup, newGroup }

class _MarioKartSetupScreenState extends State<MarioKartSetupScreen> {
  final AuthService _authService = AuthService();
  final MarioKartService _service = MarioKartService();

  final TextEditingController _groupNameController = TextEditingController();

  _SetupTab _selectedTab = _SetupTab.newGroup;

  String? _selectedGroupId;
  MarioKartCup _selectedCup = MarioKartData.allCups.first;

  // Ausgewählte Freunde per Multi-Select (beliebig viele!)
  final Set<String> _selectedFriendUids = {};

  bool _isStarting = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  void _showCupPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            final baseCups =
                MarioKartData.allCups.where((c) => c.category == 'Hauptspiel').toList();
            final boosterCups = MarioKartData.allCups
                .where((c) => c.category == 'Booster-Streckenpass')
                .toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Grand Prix Cup auswählen',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      const Text(
                        'Hauptspiel Cups (12)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...baseCups.map((cup) => _buildCupTile(cup)),
                      const SizedBox(height: 16),
                      const Text(
                        'Booster-Streckenpass Cups (12)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...boosterCups.map((cup) => _buildCupTile(cup)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCupTile(MarioKartCup cup) {
    final isSelected = cup.id == _selectedCup.id;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: isSelected ? Colors.red.shade900.withValues(alpha: 0.4) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? const BorderSide(color: Colors.redAccent, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.redAccent,
          child: Icon(Icons.emoji_events, color: Colors.white, size: 20),
        ),
        title: Text(
          cup.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.redAccent.shade100 : Colors.white,
          ),
        ),
        subtitle: Text(
          cup.tracks.join(' • '),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.redAccent) : null,
        onTap: () {
          setState(() {
            _selectedCup = cup;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _startNewGameWithNewGroup({
    required String myUid,
    required String myUsername,
    required List<Map<String, dynamic>> friends,
  }) async {
    if (_selectedFriendUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wähle mindestens einen Freund für die Runde aus.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isStarting = true);

    try {
      String groupName = _groupNameController.text.trim();
      if (groupName.isEmpty) {
        groupName = 'Mario Kart am ${DateTime.now().day}.${DateTime.now().month}.';
      }

      String getName(String uid) {
        final friend = friends.firstWhere(
          (f) => f['uid'] == uid,
          orElse: () => {'username': 'Mitspieler'},
        );
        return friend['username'] ?? 'Mitspieler';
      }

      final playerUids = [myUid, ..._selectedFriendUids];
      final playerNames = [
        myUsername,
        ..._selectedFriendUids.map((uid) => getName(uid)),
      ];

      // 1. Gruppe erstellen
      final group = await _service.createGroup(
        name: groupName,
        createdBy: myUid,
        playerUids: playerUids,
        playerNames: playerNames,
      );

      // 2. Spiel für ausgewählten Grand Prix Cup erstellen
      final game = await _service.createGame(
        group: group,
        cup: _selectedCup,
        createdBy: myUid,
      );

      if (!mounted) return;
      setState(() => _isStarting = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MarioKartScoreScreen(game: game)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Starten: $e'),
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
      final groups = await _service.getGroupsForUser(myUid);
      final group = groups.firstWhere(
        (g) => g.id == _selectedGroupId,
        orElse: () => groups.first,
      );

      final game = await _service.createGame(
        group: group,
        cup: _selectedCup,
        createdBy: myUid,
      );

      if (!mounted) return;
      setState(() => _isStarting = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MarioKartScoreScreen(game: game)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Starten: $e'),
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
        final List<String> friendUids = List<String>.from(myData['friends'] ?? []);

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _authService.getUsersByIds(friendUids),
          builder: (context, friendsSnapshot) {
            final friends = friendsSnapshot.data ?? [];

            return Scaffold(
              appBar: AppBar(
                title: const Text('Mario Kart 8 Deluxe'),
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
                          label: Text('Matches'),
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

                    // Tab Content
                    Expanded(
                      child: _buildTabContent(
                        myUid: myUid,
                        myUsername: myUsername,
                        friends: friends,
                        isLoadingFriends:
                            friendsSnapshot.connectionState == ConnectionState.waiting,
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
                          backgroundColor: Colors.redAccent.shade700,
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
                                    ? 'Gruppe anlegen & Grand Prix starten'
                                    : 'Grand Prix starten',
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

  void _confirmDeleteGame(MarioKartGame game) async {
    final bool isFinished = game.status == 'finished';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFinished ? 'Match löschen?' : 'Match verwerfen?'),
        content: Text(
          isFinished
              ? 'Möchtest du dieses Match aus der Historie entfernen?'
              : 'Möchtest du dieses laufende Match wirklich verwerfen und löschen?',
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
      await _service.deleteGame(game.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFinished ? 'Match gelöscht.' : 'Match verworfen.',
            ),
          ),
        );
      }
    }
  }

  void _finishGameFromList(MarioKartGame game) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Match beenden?'),
        content: const Text(
          'Möchtest du dieses Match als abgeschlossen markieren?',
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
      await _service.finishGame(game.id!);
    }
  }

  // --- TAB 1: Eigene Matches / Historie ---
  Widget _buildGamesList(String myUid) {
    return StreamBuilder<List<MarioKartGame>>(
      stream: _service.getUserGamesStream(myUid),
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
                const Icon(Icons.sports_esports, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Noch keine Mario Kart Matches gespielt.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedTab = _SetupTab.newGroup);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Jetzt ersten Grand Prix starten'),
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
                      isActive ? Colors.redAccent.shade700 : Colors.grey.shade800,
                  child: const Icon(Icons.emoji_events, color: Colors.white, size: 20),
                ),
                title: Text(
                  '${game.groupName} • ${game.cups.length} ${game.cups.length == 1 ? "Cup" : "Cups"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${game.playerNames.length} Fahrer: ${game.playerNames.join(', ')}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cups: ${game.cups.map((c) => c.cupName).join(', ')}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${game.races.length} Strecken absolviert • ${isActive ? "Laufend" : "Beendet"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? Colors.amberAccent : Colors.grey,
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
                          builder: (context) => MarioKartScoreScreen(game: game),
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
                            Icon(Icons.check_circle_outline, size: 18, color: Colors.greenAccent),
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
                      builder: (context) => MarioKartScoreScreen(game: game),
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

  // --- TAB 2: Bestehende Gruppe wählen ---
  Widget _buildExistingGroupsView(String myUid) {
    return StreamBuilder<List<MarioKartGroup>>(
      stream: _service.getGroupsStream(myUid),
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
                  'Du bist noch in keiner Mario Kart Gruppe.',
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

        if (_selectedGroupId == null || !groups.any((g) => g.id == _selectedGroupId)) {
          _selectedGroupId = groups.first.id;
        }

        final selectedGroup = groups.firstWhere(
          (g) => g.id == _selectedGroupId,
          orElse: () => groups.first,
        );

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Wähle deine Gruppe:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedGroupId),
                initialValue: _selectedGroupId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                ),
                items: groups.map((g) {
                  return DropdownMenuItem<String>(
                    value: g.id,
                    child: Text(
                      '${g.name} (${g.playerNames.length} Fahrer)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedGroupId = val;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Mitspieler der Gruppe
              Card(
                color: Colors.grey.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fahrer dieser Gruppe (${selectedGroup.playerNames.length}):',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: selectedGroup.playerNames.map((name) {
                          return Chip(
                            avatar: const Icon(Icons.person, size: 16),
                            label: Text(name),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Button zu den Gruppen-Statistiken & Verlauf
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarioKartGroupStatsScreen(group: selectedGroup),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined, color: Colors.blueAccent),
                label: const Text(
                  'Gruppen-Statistiken & Verlauf anzeigen',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: Colors.blueAccent.shade400, width: 1.5),
                ),
              ),

              const SizedBox(height: 20),

              // Cup Auswahl
              _buildSelectedCupCard(),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 3: Neue Gruppe erstellen mit beliebiger Spieleranzahl ---
  Widget _buildNewGroupForm({
    required String myUid,
    required String myUsername,
    required List<Map<String, dynamic>> friends,
    required bool isLoadingFriends,
  }) {
    if (isLoadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }

    if (friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline, size: 64, color: Colors.amberAccent),
              const SizedBox(height: 16),
              const Text(
                'Noch keine Freunde in der Liste',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Füge Freunde über ihr Spieler-Tag hinzu, um sie zu einer Mario Kart Runde einzuladen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FriendsScreen()),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Freunde suchen & hinzufügen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalPlayersCount = 1 + _selectedFriendUids.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _groupNameController,
            decoration: const InputDecoration(
              labelText: 'Name der Gruppe (z.B. Switch-Abend)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 20),

          // Cup Auswahl Widget
          _buildSelectedCupCard(),
          const SizedBox(height: 20),

          // Fahrer-Auswahl Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fahrer auswählen:',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.shade700.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalPlayersCount Fahrer ausgewählt',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Du (Immer dabei)
          Card(
            color: Colors.red.shade900.withValues(alpha: 0.35),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                '$myUsername (Du)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Fahrer 1 • Host'),
              trailing: const Icon(Icons.check, color: Colors.greenAccent),
            ),
          ),
          const SizedBox(height: 6),

          // Multi-Select Freunde
          const Text(
            'Wähle Mitspieler aus deinen Freunden (beliebig viele):',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          ...friends.map((friend) {
            final uid = friend['uid'] as String? ?? '';
            final username = friend['username'] ?? 'Unbekannt';
            final userTag = friend['userTag'] ?? '';
            final isChecked = _selectedFriendUids.contains(uid);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3.0),
              child: CheckboxListTile(
                value: isChecked,
                activeColor: Colors.redAccent,
                title: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(userTag, style: const TextStyle(fontSize: 12)),
                secondary: CircleAvatar(
                  backgroundColor: isChecked ? Colors.redAccent.shade700 : Colors.grey.shade800,
                  child: const Icon(Icons.sports_motorsports, color: Colors.white, size: 20),
                ),
                onChanged: (bool? val) {
                  setState(() {
                    if (val == true) {
                      _selectedFriendUids.add(uid);
                    } else {
                      _selectedFriendUids.remove(uid);
                    }
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSelectedCupCard() {
    return Card(
      color: Colors.grey.shade900,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amberAccent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Grand Prix Cup',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _showCupPickerModal,
                  child: const Text('Cup ändern', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _selectedCup.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              _selectedCup.category,
              style: TextStyle(fontSize: 13, color: Colors.redAccent.shade100),
            ),
            const SizedBox(height: 10),
            const Text(
              'Strecken (4 Maps):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            ...List.generate(_selectedCup.tracks.length, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.red.shade900,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_selectedCup.tracks[i], style: const TextStyle(fontSize: 14)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
