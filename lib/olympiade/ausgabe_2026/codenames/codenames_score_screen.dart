import 'package:flutter/material.dart';
import 'codenames_models.dart';
import 'codenames_service.dart';

const List<Color> codenamesTeamColors = [Colors.redAccent, Colors.lightBlueAccent];

class CodenamesScoreScreen extends StatefulWidget {
  final CodenamesGame game;
  final CodenamesService? service; // Optional, z.B. für Spiele einer WG Olympiade

  const CodenamesScoreScreen({super.key, required this.game, this.service});

  @override
  State<CodenamesScoreScreen> createState() => _CodenamesScoreScreenState();
}

class _CodenamesScoreScreenState extends State<CodenamesScoreScreen> {
  late final CodenamesService _service = widget.service ?? CodenamesService();

  Future<void> _addWin(CodenamesGame currentGame, int teamIndex) async {
    if (currentGame.id == null) return;
    final updatedRounds = List<CodenamesRound>.from(currentGame.rounds)
      ..add(CodenamesRound(winnerIndex: teamIndex, timestamp: DateTime.now()));
    await _service.updateRounds(game: currentGame, rounds: updatedRounds);
  }

  Future<void> _removeRound(CodenamesGame currentGame, int roundIndex) async {
    if (currentGame.id == null) return;
    final updatedRounds = List<CodenamesRound>.from(currentGame.rounds)..removeAt(roundIndex);
    await _service.updateRounds(game: currentGame, rounds: updatedRounds);
  }

  void _confirmFinishGame(CodenamesGame currentGame) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Match beenden?'),
        content: const Text(
            'Möchtest du dieses Match vorzeitig abschließen? Danach können keine Siege mehr eingetragen werden.'),
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

    if (confirm == true && currentGame.id != null) {
      await _service.finishGame(currentGame.id!);
    }
  }

  void _confirmDiscardGame(CodenamesGame currentGame) async {
    final bool isFinished = currentGame.status == 'finished';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFinished ? 'Match löschen?' : 'Match verwerfen?'),
        content: Text(
          isFinished
              ? 'Möchtest du dieses beendete Match wirklich aus der Historie löschen?'
              : 'Möchtest du dieses laufende Match wirklich abbrechen und löschen? Alle Siege werden unwiderruflich gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isFinished ? 'Löschen' : 'Match verwerfen',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && currentGame.id != null) {
      await _service.deleteGame(currentGame.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFinished ? 'Das Match wurde gelöscht.' : 'Das Match wurde abgebrochen und verworfen.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.game.id == null) {
      return _buildScaffold(widget.game);
    }

    return StreamBuilder<CodenamesGame?>(
      stream: _service.getGameStream(widget.game.id!),
      initialData: widget.game,
      builder: (context, snapshot) {
        final currentGame = snapshot.data ?? widget.game;
        return _buildScaffold(currentGame);
      },
    );
  }

  Widget _buildScaffold(CodenamesGame currentGame) {
    final bool isFinished = currentGame.status == 'finished';
    final int? winner = currentGame.winnerIndex;
    // Rückgängig ist erlaubt, solange nicht manuell beendet wurde
    final bool canUndo = currentGame.rounds.isNotEmpty && (!isFinished || winner != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Codenames'),
        centerTitle: true,
        actions: [
          if (canUndo)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Letzten Sieg rückgängig',
              onPressed: () => _removeRound(currentGame, currentGame.rounds.length - 1),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'finish') {
                _confirmFinishGame(currentGame);
              } else if (value == 'discard') {
                _confirmDiscardGame(currentGame);
              }
            },
            itemBuilder: (context) => [
              if (!isFinished)
                const PopupMenuItem(
                  value: 'finish',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('Match beenden'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'discard',
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      isFinished ? 'Match löschen' : 'Match verwerfen',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (winner != null)
            _buildWinnerBanner(currentGame, winner)
          else if (isFinished)
            _buildFinishedBanner(),

          Text(
            currentGame.winsNeeded == 1
                ? '1 Sieg zum Gesamtsieg'
                : '${currentGame.winsNeeded} Siege zum Gesamtsieg',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Die beiden Teams nebeneinander
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTeamCard(currentGame, 0, canAddWin: !isFinished)),
                const SizedBox(width: 12),
                Expanded(child: _buildTeamCard(currentGame, 1, canAddWin: !isFinished)),
              ],
            ),
          ),

          const Divider(height: 32, thickness: 2),

          // Verlauf der Partien
          ..._buildHistory(currentGame, isFinished),
        ],
      ),
    );
  }

  Widget _buildWinnerBanner(CodenamesGame game, int winner) {
    final color = codenamesTeamColors[winner];
    return Card(
      color: color.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color, width: 2),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 40, color: color),
            const SizedBox(height: 6),
            Text(
              '${game.teams[winner].name} gewinnt!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
            Text(
              game.teams[winner].playerNames.join(', '),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Siege: ${game.wins.join(' : ')}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag, size: 18, color: Colors.orangeAccent),
          SizedBox(width: 8),
          Text(
            'Dieses Match wurde vorzeitig beendet',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(CodenamesGame game, int teamIndex, {required bool canAddWin}) {
    final color = codenamesTeamColors[teamIndex];
    final team = game.teams[teamIndex];
    final wins = game.wins[teamIndex];

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Text(
              team.name,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              team.playerNames.join(', '),
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$wins',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: wins > 0 ? Colors.white : Colors.grey,
              ),
            ),
            // Fortschritt bis zum Gesamtsieg
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: List.generate(game.winsNeeded, (i) {
                final won = i < wins;
                return Icon(
                  won ? Icons.circle : Icons.circle_outlined,
                  size: 12,
                  color: won ? color : Colors.grey,
                );
              }),
            ),
            const Spacer(),
            if (canAddWin) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withValues(alpha: 0.2),
                    foregroundColor: color,
                    side: BorderSide(color: color, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _addWin(game, teamIndex),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Sieg',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHistory(CodenamesGame game, bool isFinished) {
    final counted = game.countedRounds;
    if (counted.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'Noch keine Partien gespielt.\nTippe auf „+ Sieg“ beim Gewinnerteam.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }

    // Zwischenstände berechnen
    final running = [0, 0];
    final rows = <Widget>[];
    for (int i = 0; i < counted.length; i++) {
      final round = counted[i];
      running[round.winnerIndex]++;
      final color = codenamesTeamColors[round.winnerIndex];

      rows.add(ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: color.withValues(alpha: 0.25),
          child: Text(
            '${i + 1}',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          'Partie ${i + 1}: ${game.teams[round.winnerIndex].name}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text('Stand ${running.join(' : ')}'),
        trailing: isFinished
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                tooltip: 'Partie löschen',
                onPressed: () => _removeRound(game, i),
              ),
      ));
    }

    return [
      const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text('Verlauf', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      ...rows.reversed,
    ];
  }
}
