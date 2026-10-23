import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_counter/auth_service.dart';
import 'package:game_counter/friends_screen.dart';
import 'package:game_counter/olympiade/olympiade_disciplines.dart';
import 'package:game_counter/olympiade/olympiade_editions.dart';
import 'halbieren_models.dart';
import 'halbieren_service.dart';
import 'halbieren_score_screen.dart';

const List<String> _teamNames = ['Team 1', 'Team 2'];

class HalbierenSetupScreen extends StatefulWidget {
  const HalbierenSetupScreen({super.key});

  @override
  State<HalbierenSetupScreen> createState() => _HalbierenSetupScreenState();
}

enum _SetupTab { games, newGame }

class _HalbierenSetupScreenState extends State<HalbierenSetupScreen> {
  final AuthService _authService = AuthService();
  final HalbierenService _service = HalbierenService();

  _SetupTab _selectedTab = _SetupTab.newGame;

  // Spieler-UIDs pro Team (Index 0 = Team 1, 1 = Team 2)
  final List<List<String>> _teamUids = [[], []];
  bool _initializedMe = false;

  // Ablauf (Akte & Lebensmittel) aus der aktuellen Ausgabe der WG Olympiade
  final OlympiadeEdition _edition = olympiadeEditions.first;
  late final List<TeilenFood> _foods = olympiadeTeilenFoods(_edition);

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
        return HalbierenTeam(
          name: _teamNames[t],
          playerUids: List<String>.from(_teamUids[t]),
          playerNames: _teamUids[t].map((uid) => playerNames[uid] ?? 'Mitspieler').toList(),
        );
      });

      final game = await _service.createGame(
        createdBy: myUid,
        teams: teams,
        foods: _foods,
        secondsPerFood: _edition.teilenSecondsPerFood,
      );

      if (!mounted) return;
      setState(() => _isStarting = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HalbierenScoreScreen(game: game)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      _showError('Fehler beim Starten: $e');
    }
  }

  void _showAddPlayerSheet(int teamIndex, Map<String, String> playerNames, String myUid) {
    final color = halbierenTeamColors[teamIndex];

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
                title: const Text('Das Große Teilen'),
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
                          label: Text('Matches'),
                          icon: Icon(Icons.history),
                        ),
                        ButtonSegment(
                          value: _SetupTab.newGame,
                          label: Text('Neues Match'),
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
                          backgroundColor: Colors.orange.shade800,
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
                                'Match starten',
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

  void _confirmDeleteGame(HalbierenGame game) async {
    final bool isFinished = game.status == 'finished';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFinished ? 'Match löschen?' : 'Match verwerfen?'),
        content: Text(
          isFinished
              ? 'Möchtest du dieses Match aus der Historie entfernen?'
              : 'Möchtest du dieses laufende Match wirklich abbrechen und verwerfen?',
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
          SnackBar(content: Text(isFinished ? 'Match gelöscht.' : 'Match verworfen.')),
        );
      }
    }
  }

  // --- TAB 1: Eigene Matches / Historie ---
  Widget _buildGamesList(String myUid) {
    return StreamBuilder<List<HalbierenGame>>(
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
                const Icon(Icons.content_cut, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Noch keine Spiele.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedTab = _SetupTab.newGame);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Jetzt erstes Match starten'),
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
                  backgroundColor: isActive ? Colors.orange.shade800 : Colors.grey.shade800,
                  child: const Icon(Icons.content_cut, color: Colors.white, size: 20),
                ),
                title: Text(
                  game.teams.map((t) => t.playerNames.join(' & ')).join('  vs.  '),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${game.doneCount}/${game.foods.length} geteilt  •  '
                      '${game.totals.map(formatTeilenPercent).join(' : ')}  •  '
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
                            ? halbierenTeamColors[winner]
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
                    MaterialPageRoute(builder: (context) => HalbierenScoreScreen(game: game)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: Neues Match ---
  Widget _buildNewGameForm({
    required String myUid,
    required Map<String, String> playerNames,
    required bool hasFriends,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ablauf aus dem aktuellen Regelwerk der WG Olympiade
          Card(
            color: Colors.grey.shade900,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orangeAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_foods.length} Lebensmittel in ${_edition.teilenActs.length} Akten, '
                      '${_edition.teilenSecondsPerFood ~/ 60} Minuten pro Lebensmittel. '
                      'Die kleinere Gesamtabweichung gewinnt.',
                    ),
                  ),
                ],
              ),
            ),
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
    final color = halbierenTeamColors[teamIndex];
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
