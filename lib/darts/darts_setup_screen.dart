import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_counter/auth_service.dart';
import 'package:game_counter/friends_screen.dart';
import 'darts_models.dart';
import 'darts_service.dart';
import 'darts_score_screen.dart';

class DartsSetupScreen extends StatefulWidget {
  const DartsSetupScreen({super.key});

  @override
  State<DartsSetupScreen> createState() => _DartsSetupScreenState();
}

enum _SetupTab { games, newGame }

class _DartsSetupScreenState extends State<DartsSetupScreen> {
  final AuthService _authService = AuthService();
  final DartsService _service = DartsService();

  _SetupTab _selectedTab = _SetupTab.newGame;

  String? _opponentUid;
  int _legsToWin = 3;

  bool _isStarting = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _startGame({
    required String myUid,
    required String myUsername,
    required List<Map<String, dynamic>> friends,
  }) async {
    if (_opponentUid == null) {
      _showError('Bitte wähle einen Gegner aus.');
      return;
    }

    setState(() => _isStarting = true);

    try {
      final opponent = friends.firstWhere(
        (f) => f['uid'] == _opponentUid,
        orElse: () => {'username': 'Gegner'},
      );

      final game = await _service.createGame(
        createdBy: myUid,
        playerUids: [myUid, _opponentUid!],
        playerNames: [myUsername, opponent['username'] ?? 'Gegner'],
        legsToWin: _legsToWin,
      );

      if (!mounted) return;
      setState(() => _isStarting = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DartsScoreScreen(game: game)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      _showError('Fehler beim Starten: $e');
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
            final bool isLoadingFriends =
                friendsSnapshot.connectionState == ConnectionState.waiting;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Dart'),
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
                          : _buildNewGameForm(
                              myUsername: myUsername,
                              friends: friends,
                              isLoadingFriends: isLoadingFriends,
                            ),
                    ),
                    if (_selectedTab == _SetupTab.newGame && friends.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isStarting
                            ? null
                            : () => _startGame(
                                  myUid: myUid,
                                  myUsername: myUsername,
                                  friends: friends,
                                ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green.shade700,
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

  void _confirmDeleteGame(DartsGame game) async {
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
    return StreamBuilder<List<DartsGame>>(
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
                const Icon(Icons.gps_fixed, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Noch keine Dart-Matches.',
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
                  backgroundColor: isActive ? Colors.green.shade700 : Colors.grey.shade800,
                  child: const Icon(Icons.gps_fixed, color: Colors.white, size: 20),
                ),
                title: Text(
                  game.playerNames.join('  vs.  '),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Legs ${game.legsWon.join(' : ')}  •  First to ${game.legsToWin}  •  '
                      '${game.date.day}.${game.date.month}.${game.date.year}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      winner != null
                          ? '${game.playerNames[winner]} hat gewonnen'
                          : (isActive ? 'Laufend' : 'Abgebrochen'),
                      style: TextStyle(
                        fontSize: 12,
                        color: winner != null
                            ? dartsPlayerColors[winner]
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
                    MaterialPageRoute(builder: (context) => DartsScoreScreen(game: game)),
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
                'Füge Freunde über ihr Spieler-Tag hinzu, um gegen sie Dart zu spielen.',
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
          // Modus: Legs zum Sieg
          const Text(
            'Legs zum Sieg',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [1, 2, 3, 5, 7].map((n) {
                    return ChoiceChip(
                      label: Text('$n'),
                      selected: _legsToWin == n,
                      onSelected: (_) => setState(() => _legsToWin = n),
                    );
                  }).toList(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _legsToWin > 1 ? () => setState(() => _legsToWin--) : null,
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$_legsToWin',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _legsToWin < 21 ? () => setState(() => _legsToWin++) : null,
              ),
            ],
          ),
          Text(
            'First to $_legsToWin • Best of ${_legsToWin * 2 - 1}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Spieler
          const Text(
            'Spieler',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.green.shade900.withValues(alpha: 0.35),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.greenAccent,
                child: Icon(Icons.person, color: Colors.black),
              ),
              title: Text(
                '$myUsername (Du)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Spieler 1'),
              trailing: const Icon(Icons.lock, size: 18, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Gegner auswählen:',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          RadioGroup<String>(
            groupValue: _opponentUid,
            onChanged: (val) => setState(() => _opponentUid = val),
            child: Column(
              children: friends.map((friend) {
                final uid = friend['uid'] as String? ?? '';
                final username = friend['username'] ?? 'Unbekannt';
                final userTag = friend['userTag'] ?? '';
                final isSelected = _opponentUid == uid;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 3.0),
                  child: RadioListTile<String>(
                    value: uid,
                    activeColor: Colors.redAccent,
                    title: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(userTag, style: const TextStyle(fontSize: 12)),
                    secondary: CircleAvatar(
                      backgroundColor: isSelected ? Colors.redAccent : Colors.grey.shade800,
                      child: const Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
