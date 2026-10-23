import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_counter/auth_service.dart';
import 'package:game_counter/friends_screen.dart';
import 'bierpong_models.dart';
import 'bierpong_service.dart';

class BierpongScreen extends StatefulWidget {
  const BierpongScreen({super.key});

  @override
  State<BierpongScreen> createState() => _BierpongScreenState();
}

enum _Tab { games, newGame }

class _BierpongScreenState extends State<BierpongScreen> {
  final AuthService _authService = AuthService();
  final BierpongService _service = BierpongService();

  _Tab _selectedTab = _Tab.newGame;

  String? _opponentUid;
  bool _isSaving = false;

  void _saveResult({
    required String myUid,
    required String myUsername,
    required String opponentName,
    required int winnerIndex,
  }) async {
    if (_opponentUid == null) return;

    setState(() => _isSaving = true);

    try {
      await _service.saveGame(
        createdBy: myUid,
        playerUids: [myUid, _opponentUid!],
        playerNames: [myUsername, opponentName],
        winnerIndex: winnerIndex,
      );

      if (!mounted) return;
      final winnerName = winnerIndex == 0 ? myUsername : opponentName;
      setState(() {
        _isSaving = false;
        _selectedTab = _Tab.games;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gespeichert: $winnerName hat gewonnen 🍺')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _confirmDeleteGame(BierpongGame game) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spiel löschen?'),
        content: Text(
          'Möchtest du das Spiel ${game.playerNames.join(' vs. ')} '
          '(Sieger: ${game.winnerName}) wirklich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true && game.id != null) {
      await _service.deleteGame(game.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spiel gelöscht.')),
        );
      }
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
                title: const Text('Bierpong'),
                centerTitle: true,
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<_Tab>(
                      segments: const [
                        ButtonSegment(
                          value: _Tab.games,
                          label: Text('Spiele & Bilanz'),
                          icon: Icon(Icons.history),
                        ),
                        ButtonSegment(
                          value: _Tab.newGame,
                          label: Text('Ergebnis'),
                          icon: Icon(Icons.add),
                        ),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (Set<_Tab> newSelection) {
                        setState(() {
                          _selectedTab = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _selectedTab == _Tab.games
                          ? _buildGamesList(myUid)
                          : (isLoadingFriends
                              ? const Center(child: CircularProgressIndicator())
                              : _buildNewGameForm(
                                  myUid: myUid,
                                  myUsername: myUsername,
                                  friends: friends,
                                )),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 1: Bilanz & Historie ---
  Widget _buildGamesList(String myUid) {
    return StreamBuilder<List<BierpongGame>>(
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
                const Icon(Icons.sports_bar, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Noch keine Bierpong-Spiele.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedTab = _Tab.newGame);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Erstes Ergebnis eintragen'),
                ),
              ],
            ),
          );
        }

        final records = bierpongRecordsFor(myUid, games);
        final totalWins = records.fold<int>(0, (total, r) => total + r.wins);
        final totalLosses = records.fold<int>(0, (total, r) => total + r.losses);

        return ListView(
          children: [
            // Gesamtbilanz
            Card(
              color: Colors.grey.shade900,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deine Bilanz',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('$totalWins', 'Siege', Colors.greenAccent),
                        _buildStat('$totalLosses', 'Niederlagen', Colors.redAccent),
                        _buildStat(
                          totalWins + totalLosses == 0
                              ? '–'
                              : '${(totalWins * 100 / (totalWins + totalLosses)).round()}%',
                          'Siegquote',
                          Colors.yellowAccent,
                        ),
                      ],
                    ),
                    if (records.isNotEmpty) ...[
                      const Divider(height: 24),
                      ...records.map((r) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(child: Text('gegen ${r.opponentName}')),
                              Text(
                                '${r.wins}',
                                style: const TextStyle(
                                    color: Colors.greenAccent, fontWeight: FontWeight.bold),
                              ),
                              const Text(' : '),
                              Text(
                                '${r.losses}',
                                style: const TextStyle(
                                    color: Colors.redAccent, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Letzte Spiele',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),

            // Einzelne Spiele
            ...games.map((game) {
              final myIndex = game.playerUids.indexOf(myUid);
              final bool iWon = game.winnerIndex == myIndex;
              final opponentName = myIndex >= 0 && game.playerNames.length == 2
                  ? game.playerNames[1 - myIndex]
                  : game.playerNames.join(' vs. ');

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: iWon
                        ? Colors.greenAccent.withValues(alpha: 0.25)
                        : Colors.redAccent.withValues(alpha: 0.25),
                    child: Icon(
                      iWon ? Icons.emoji_events : Icons.close,
                      color: iWon ? Colors.greenAccent : Colors.redAccent,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'gegen $opponentName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${iWon ? "Gewonnen" : "Verloren"}  •  '
                    '${game.date.day}.${game.date.month}.${game.date.year}',
                    style: TextStyle(
                      color: iWon ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                    tooltip: 'Löschen',
                    onPressed: () => _confirmDeleteGame(game),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // --- TAB 2: Ergebnis eintragen ---
  Widget _buildNewGameForm({
    required String myUid,
    required String myUsername,
    required List<Map<String, dynamic>> friends,
  }) {
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
                'Füge Freunde über ihr Spieler-Tag hinzu, um gegen sie Bierpong zu spielen.',
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

    final opponent = friends.firstWhere(
      (f) => f['uid'] == _opponentUid,
      orElse: () => {},
    );
    final String? opponentName =
        _opponentUid != null ? (opponent['username'] ?? 'Gegner') : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '1. Gegner auswählen',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: RadioGroup<String>(
            groupValue: _opponentUid,
            onChanged: (val) => setState(() => _opponentUid = val),
            child: ListView(
              children: friends.map((friend) {
                final uid = friend['uid'] as String? ?? '';
                final username = friend['username'] ?? 'Unbekannt';
                final userTag = friend['userTag'] ?? '';
                final isSelected = _opponentUid == uid;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 3.0),
                  child: RadioListTile<String>(
                    value: uid,
                    activeColor: Colors.yellowAccent,
                    title: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(userTag, style: const TextStyle(fontSize: 12)),
                    secondary: CircleAvatar(
                      backgroundColor: isSelected ? Colors.yellow.shade800 : Colors.grey.shade800,
                      child: const Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '2. Wer hat gewonnen?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildWinnerButton(
                label: myUsername,
                sublabel: 'Du',
                onPressed: opponentName == null || _isSaving
                    ? null
                    : () => _saveResult(
                          myUid: myUid,
                          myUsername: myUsername,
                          opponentName: opponentName,
                          winnerIndex: 0,
                        ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildWinnerButton(
                label: opponentName ?? 'Gegner',
                sublabel: opponentName == null ? 'erst auswählen' : 'Gegner',
                onPressed: opponentName == null || _isSaving
                    ? null
                    : () => _saveResult(
                          myUid: myUid,
                          myUsername: myUsername,
                          opponentName: opponentName,
                          winnerIndex: 1,
                        ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWinnerButton({
    required String label,
    required String sublabel,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.yellowAccent.withValues(alpha: 0.15),
        foregroundColor: Colors.yellowAccent,
        side: BorderSide(
          color: onPressed == null ? Colors.grey.shade700 : Colors.yellowAccent,
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      ),
      onPressed: onPressed,
      child: Column(
        children: [
          const Icon(Icons.emoji_events, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(sublabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
