import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_counter/auth_service.dart';
import 'package:game_counter/friends_screen.dart';
import 'basketball_models.dart';
import 'basketball_service.dart';
import 'basketball_score_screen.dart';

const List<String> _teamNames = ['Team 1', 'Team 2'];

class BasketballSetupScreen extends StatefulWidget {
  const BasketballSetupScreen({super.key});

  @override
  State<BasketballSetupScreen> createState() => _BasketballSetupScreenState();
}

enum _SetupTab { games, newGame }

class _BasketballSetupScreenState extends State<BasketballSetupScreen> {
  final AuthService _authService = AuthService();
  final BasketballService _service = BasketballService();

  _SetupTab _selectedTab = _SetupTab.newGame;

  // Spieler-UIDs pro Team (Index 0 = Team 1, 1 = Team 2)
  final List<List<String>> _teamUids = [[], []];
  bool _initializedMe = false;

  int _winsNeeded = 2;

  bool _isStarting = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _startGame({
    required String myUid,
    required Map<String, String> playerNames,
  }) async {
    for (int t = 0; t < 2; t++) {
      if (_teamUids[t].isEmpty) {
        _showError('${_teamNames[t]} hat noch keine Spieler.');
        return;
      }
    }

    setState(() => _isStarting = true);

    try {
      final teams = List.generate(2, (t) {
        return BasketballTeam(
          name: _teamNames[t],
          playerUids: List<String>.from(_teamUids[t]),
          playerNames: _teamUids[t].map((uid) => playerNames[uid] ?? 'Mitspieler').toList(),
        );
      });

      final game = await _service.createGame(
        createdBy: myUid,
        teams: teams,
        winsNeeded: _winsNeeded,
      );

      if (!mounted) return;
      setState(() => _isStarting = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BasketballScoreScreen(game: game)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      _showError('Fehler beim Starten: $e');
    }
  }

  void _showAddPlayerSheet(int teamIndex, Map<String, String> playerNames, String myUid) {
    final color = basketballTeamColors[teamIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final available = playerNames.entries
                .where((e) => !_teamUids[0].contains(e.key) && !_teamUids[1].contains(e.key))
                .toList();

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Spieler zu ${_teamNames[teamIndex]} hinzufügen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (available.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'Alle Spieler sind bereits einem Team zugeordnet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: available.map((entry) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.25),
                              child: Icon(Icons.person, color: color, size: 20),
                            ),
                            title: Text(entry.key == myUid ? '${entry.value} (Du)' : entry.value),
                            trailing: Icon(Icons.add_circle_outline, color: color),
                            onTap: () {
                              setState(() => _teamUids[teamIndex].add(entry.key));
                              setSheetState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Fertig'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUserId;

    if (myUid == null) {
      return const Scaffold(
        body: Center(child: Text('Bitte melde dich zuerst an.')),
      );
    }

    if (!_initializedMe) {
      _teamUids[0].add(myUid);
      _initializedMe = true;
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
            final bool isLoadingFriends =
                friendsSnapshot.connectionState == ConnectionState.waiting;

            // Alle verfügbaren Spieler: du + deine Freunde
            final playerNames = <String, String>{
              myUid: myUsername,
              for (final f in friends)
                if (f['uid'] is String) f['uid'] as String: f['username'] ?? 'Unbekannt',
            };

            return Scaffold(
              appBar: AppBar(
                title: const Text('Basketball'),
                centerTitle: true,
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<_SetupTab>(
                      segments: const [
                        ButtonSegment(
                          value: _SetupTab.games,
                          label: Text('Spiele'),
                          icon: Icon(Icons.history),
                        ),
                        ButtonSegment(
                          value: _SetupTab.newGame,
                          label: Text('Neues Spiel'),
                          icon: Icon(Icons.add),
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
                    Expanded(
                      child: _selectedTab == _SetupTab.games
                          ? _buildGamesList(myUid)
                          : (isLoadingFriends
                              ? const Center(child: CircularProgressIndicator())
                              : _buildNewGameForm(
                                  myUid: myUid,
                                  playerNames: playerNames,
                                  hasFriends: friends.isNotEmpty,
                                )),
                    ),
                    if (_selectedTab == _SetupTab.newGame && !isLoadingFriends) ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isStarting
                            ? null
                            : () => _startGame(myUid: myUid, playerNames: playerNames),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.deepOrange.shade700,
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
                            : const Text(
                                'Spiel starten',
                                style: TextStyle(
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

  void _confirmDeleteGame(BasketballGame game) async {
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
      await _service.deleteGame(game.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isFinished ? 'Spiel gelöscht.' : 'Spiel verworfen.')),
        );
      }
    }
  }

  // --- TAB 1: Eigene Spiele / Historie ---
  Widget _buildGamesList(String myUid) {
    return StreamBuilder<List<BasketballGame>>(
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
                const Icon(Icons.sports_basketball, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Noch keine Basketball-Spiele.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedTab = _SetupTab.newGame);
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
            final int? winner = game.winnerIndex;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActive ? Colors.deepOrange.shade700 : Colors.grey.shade800,
                  child: const Icon(Icons.sports_basketball, color: Colors.white, size: 20),
                ),
                title: Text(
                  game.teams.map((t) => t.playerNames.join(' & ')).join('  vs.  '),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Siege ${game.wins.join(' : ')}  •  Best of ${game.winsNeeded * 2 - 1}  •  '
                      '${game.date.day}.${game.date.month}.${game.date.year}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      winner != null
                          ? '${game.teams[winner].name} hat gewonnen'
                          : (isActive ? 'Laufend' : 'Abgebrochen'),
                      style: TextStyle(
                        fontSize: 12,
                        color: winner != null
                            ? basketballTeamColors[winner]
                            : (isActive ? Colors.amberAccent : Colors.grey),
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: isActive ? 'Verwerfen' : 'Löschen',
                  onPressed: () => _confirmDeleteGame(game),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BasketballScoreScreen(game: game)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: Neues Spiel ---
  Widget _buildNewGameForm({
    required String myUid,
    required Map<String, String> playerNames,
    required bool hasFriends,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Modus: Siege zum Gesamtsieg (Best of)
          const Text(
            'Siege zum Gesamtsieg',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [1, 2, 3, 4].map((n) {
                    return ChoiceChip(
                      label: Text('$n'),
                      selected: _winsNeeded == n,
                      onSelected: (_) => setState(() => _winsNeeded = n),
                    );
                  }).toList(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _winsNeeded > 1 ? () => setState(() => _winsNeeded--) : null,
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$_winsNeeded',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _winsNeeded < 21 ? () => setState(() => _winsNeeded++) : null,
              ),
            ],
          ),
          Text(
            'Best of ${_winsNeeded * 2 - 1} • wer zuerst $_winsNeeded ${_winsNeeded == 1 ? "Partie" : "Partien"} gewinnt',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Teams
          ...List.generate(2, (t) => _buildTeamEditor(t, playerNames, myUid)),

          if (!hasFriends) ...[
            const SizedBox(height: 8),
            const Text(
              'Du hast noch keine Freunde in deiner Liste. Füge Freunde hinzu, um sie in die Teams einzuteilen.',
              style: TextStyle(color: Colors.amberAccent, fontSize: 13),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FriendsScreen()),
                );
              },
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Freunde hinzufügen'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamEditor(int teamIndex, Map<String, String> playerNames, String myUid) {
    final color = basketballTeamColors[teamIndex];
    final uids = _teamUids[teamIndex].where(playerNames.containsKey).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 14, color: color),
                const SizedBox(width: 8),
                Text(
                  _teamNames[teamIndex],
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
                ),
                const Spacer(),
                Text(
                  '${uids.length} Spieler',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (uids.isEmpty)
              const Text('Noch keine Spieler', style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: uids.map((uid) {
                  final name = playerNames[uid]!;
                  return Chip(
                    label: Text(uid == myUid ? '$name (Du)' : name),
                    side: BorderSide(color: color.withValues(alpha: 0.6)),
                    onDeleted: () => setState(() => _teamUids[teamIndex].remove(uid)),
                  );
                }).toList(),
              ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => _showAddPlayerSheet(teamIndex, playerNames, myUid),
              icon: Icon(Icons.person_add_alt_1, color: color, size: 18),
              label: Text('Spieler hinzufügen', style: TextStyle(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
