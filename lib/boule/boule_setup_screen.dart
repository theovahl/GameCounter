import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_counter/auth_service.dart';
import 'package:game_counter/friends_screen.dart';
import 'boule_models.dart';
import 'boule_service.dart';
import 'boule_score_screen.dart';

class BouleSetupScreen extends StatefulWidget {
  const BouleSetupScreen({super.key});

  @override
  State<BouleSetupScreen> createState() => _BouleSetupScreenState();
}

enum _SetupTab { games, newGame }

class _BouleSetupScreenState extends State<BouleSetupScreen> {
  final AuthService _authService = AuthService();
  final BouleService _service = BouleService();

  _SetupTab _selectedTab = _SetupTab.newGame;
  int _currentStep = 0;

  // Schritt 1: Anzahl Teams
  int _teamCount = 2;

  // Schritt 2: Zuordnung Spieler-UID -> Team-Index (nicht enthalten = spielt nicht mit)
  final Map<String, int> _playerTeams = {};
  bool _initializedMe = false;

  // Schritt 3: Modus
  int _pointsPerSet = 13;
  int _setsToWin = 1;

  bool _isStarting = false;

  void _setTeamCount(int count) {
    setState(() {
      _teamCount = count;
      // Spieler in nicht mehr existierenden Teams wieder freigeben
      _playerTeams.removeWhere((_, team) => team >= count);
    });
  }

  String? _validatePlayers() {
    for (int t = 0; t < _teamCount; t++) {
      if (!_playerTeams.values.contains(t)) {
        return 'Team ${t + 1} hat noch keine Spieler.';
      }
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _onStepContinue({
    required String myUid,
    required Map<String, String> playerNames,
  }) {
    if (_currentStep == 1) {
      final error = _validatePlayers();
      if (error != null) {
        _showError(error);
        return;
      }
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _startGame(myUid: myUid, playerNames: playerNames);
    }
  }

  void _startGame({
    required String myUid,
    required Map<String, String> playerNames,
  }) async {
    final error = _validatePlayers();
    if (error != null) {
      setState(() => _currentStep = 1);
      _showError(error);
      return;
    }

    setState(() => _isStarting = true);

    try {
      final teams = List.generate(_teamCount, (t) {
        final uids = playerNames.keys.where((uid) => _playerTeams[uid] == t).toList();
        return BouleTeam(
          name: 'Team ${t + 1}',
          playerUids: uids,
          playerNames: uids.map((uid) => playerNames[uid] ?? 'Mitspieler').toList(),
        );
      });

      final game = await _service.createGame(
        createdBy: myUid,
        teams: teams,
        pointsPerSet: _pointsPerSet,
        setsToWin: _setsToWin,
      );

      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _currentStep = 0;
      });

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BouleScoreScreen(game: game)),
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

    if (!_initializedMe) {
      _playerTeams[myUid] = 0;
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

            return Scaffold(
              appBar: AppBar(
                title: const Text('Boule'),
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
                    const SizedBox(height: 8),
                    Expanded(
                      child: _selectedTab == _SetupTab.games
                          ? _buildGamesList(myUid)
                          : _buildNewGameStepper(
                              myUid: myUid,
                              myUsername: myUsername,
                              friends: friends,
                              isLoadingFriends:
                                  friendsSnapshot.connectionState == ConnectionState.waiting,
                            ),
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

  void _confirmDeleteGame(BouleGame game) async {
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
    return StreamBuilder<List<BouleGame>>(
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
                const Icon(Icons.scatter_plot, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Noch keine Boule-Spiele.',
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
            final int? winner = game.winnerTeam;
            final scoreText = game.setsToWin > 1
                ? 'Sätze ${game.setsWon.join(' : ')}'
                : game.sets.first.scores.join(' : ');

            void open() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BouleScoreScreen(game: game)),
              );
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isActive ? Colors.lightBlueAccent.shade700 : Colors.grey.shade800,
                  child: const Icon(Icons.scatter_plot, color: Colors.white, size: 20),
                ),
                title: Text(
                  game.teams.map((t) => t.playerNames.join(' & ')).join('  vs.  '),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$scoreText  •  ${game.date.day}.${game.date.month}.${game.date.year}',
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
                            ? bouleTeamColor(winner)
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
                onTap: open,
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: Neues Spiel in drei Schritten ---
  Widget _buildNewGameStepper({
    required String myUid,
    required String myUsername,
    required List<Map<String, dynamic>> friends,
    required bool isLoadingFriends,
  }) {
    if (isLoadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }

    // Alle verfügbaren Spieler: du + deine Freunde
    final playerNames = <String, String>{
      myUid: myUsername,
      for (final f in friends)
        if (f['uid'] is String) f['uid'] as String: f['username'] ?? 'Unbekannt',
    };

    return Stepper(
      currentStep: _currentStep,
      margin: EdgeInsets.zero,
      onStepTapped: (step) {
        // Nach vorne springen nur mit gültiger Spielerzuordnung
        if (step == 2 && _validatePlayers() != null) {
          _showError(_validatePlayers()!);
          setState(() => _currentStep = 1);
          return;
        }
        setState(() => _currentStep = step);
      },
      onStepContinue: () => _onStepContinue(myUid: myUid, playerNames: playerNames),
      onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
      controlsBuilder: (context, details) {
        final isLast = details.currentStep == 2;
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: _isStarting ? null : details.onStepContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLast ? Colors.lightBlueAccent.shade700 : Colors.white,
                  foregroundColor: isLast ? Colors.white : Colors.black,
                ),
                child: _isStarting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isLast ? 'Spiel starten' : 'Weiter',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(width: 8),
              if (details.onStepCancel != null)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Zurück'),
                ),
            ],
          ),
        );
      },
      steps: [
        Step(
          title: const Text('Anzahl Teams'),
          subtitle: Text('$_teamCount Teams'),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          content: _buildTeamCountStep(),
        ),
        Step(
          title: const Text('Spieler zuordnen'),
          subtitle: Text('${_playerTeams.length} Spieler'),
          isActive: _currentStep >= 1,
          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          content: _buildPlayersStep(myUid: myUid, playerNames: playerNames, hasFriends: friends.isNotEmpty),
        ),
        Step(
          title: const Text('Modus'),
          subtitle: Text(
            '$_pointsPerSet Punkte • ${_setsToWin == 1 ? "1 Gewinnsatz" : "$_setsToWin Gewinnsätze"}',
          ),
          isActive: _currentStep >= 2,
          content: _buildModeStep(),
        ),
      ],
    );
  }

  // Schritt 1
  Widget _buildTeamCountStep() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(5, (i) {
          final count = i + 2;
          return ChoiceChip(
            label: Text('$count Teams'),
            selected: _teamCount == count,
            onSelected: (_) => _setTeamCount(count),
          );
        }),
      ),
    );
  }

  // Schritt 2
  Widget _buildPlayersStep({
    required String myUid,
    required Map<String, String> playerNames,
    required bool hasFriends,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Übersicht der Teams
        ...List.generate(_teamCount, (t) {
          final color = bouleTeamColor(t);
          final members = playerNames.entries
              .where((e) => _playerTeams[e.key] == t)
              .map((e) => e.value)
              .toList();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: color),
                const SizedBox(width: 8),
                Text(
                  'Team ${t + 1}: ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                Expanded(
                  child: Text(
                    members.isEmpty ? 'noch leer' : members.join(', '),
                    style: TextStyle(color: members.isEmpty ? Colors.grey : Colors.white),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        const Text(
          'Tippe auf ein Team, um den Spieler zuzuordnen:',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 6),

        // Ein Eintrag pro Spieler mit Team-Auswahl
        ...playerNames.entries.map((entry) {
          final uid = entry.key;
          final assigned = _playerTeams[uid];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uid == myUid ? '${entry.value} (Du)' : entry.value,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: List.generate(_teamCount, (t) {
                      final color = bouleTeamColor(t);
                      return ChoiceChip(
                        label: Text('Team ${t + 1}'),
                        selected: assigned == t,
                        selectedColor: color.withValues(alpha: 0.35),
                        side: BorderSide(color: assigned == t ? color : Colors.grey.shade700),
                        visualDensity: VisualDensity.compact,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _playerTeams[uid] = t;
                            } else {
                              _playerTeams.remove(uid);
                            }
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        }),

        if (!hasFriends || playerNames.length < _teamCount) ...[
          const SizedBox(height: 8),
          Text(
            'Du brauchst mindestens $_teamCount Spieler. Füge weitere Freunde hinzu, um sie einzuteilen.',
            style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
          ),
        ],
        const SizedBox(height: 4),
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
    );
  }

  // Schritt 3
  Widget _buildModeStep() {
    final summary = _setsToWin == 1
        ? 'Es wird ein Satz bis $_pointsPerSet Punkte gespielt.'
        : 'Gewonnen hat das Team, das zuerst $_setsToWin Sätze bis je $_pointsPerSet Punkte gewinnt'
            '${_teamCount == 2 ? ' (Best of ${_setsToWin * 2 - 1})' : ''}.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Punkte pro Satz', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _buildNumberSelector(
          value: _pointsPerSet,
          presets: const [7, 11, 13, 15],
          min: 1,
          max: 99,
          onChanged: (v) => setState(() => _pointsPerSet = v),
        ),
        const SizedBox(height: 16),
        const Text('Gewinnsätze', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _buildNumberSelector(
          value: _setsToWin,
          presets: const [1, 2, 3],
          min: 1,
          max: 9,
          onChanged: (v) => setState(() => _setsToWin = v),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.grey.shade900,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.lightBlueAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(summary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberSelector({
    required int value,
    required List<int> presets,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: presets.map((p) {
              return ChoiceChip(
                label: Text('$p'),
                selected: value == p,
                onSelected: (_) => onChanged(p),
              );
            }).toList(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
