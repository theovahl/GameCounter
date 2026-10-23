import 'package:flutter/material.dart';
import 'darts_models.dart';
import 'darts_service.dart';

const List<Color> dartsPlayerColors = [Colors.greenAccent, Colors.redAccent];

class DartsScoreScreen extends StatefulWidget {
  final DartsGame game;
  final DartsService? service; // Optional, z.B. für Spiele einer WG Olympiade

  const DartsScoreScreen({super.key, required this.game, this.service});

  @override
  State<DartsScoreScreen> createState() => _DartsScoreScreenState();
}

class _DartsScoreScreenState extends State<DartsScoreScreen> {
  late final DartsService _service = widget.service ?? DartsService();

  Future<void> _addLeg(DartsGame currentGame, int winnerIndex) async {
    if (currentGame.id == null) return;
    final updatedLegs = List<DartsLeg>.from(currentGame.legs)
      ..add(DartsLeg(winnerIndex: winnerIndex, timestamp: DateTime.now()));
    await _service.updateLegs(game: currentGame, legs: updatedLegs);
  }

  Future<void> _removeLeg(DartsGame currentGame, int legIndex) async {
    if (currentGame.id == null) return;
    final updatedLegs = List<DartsLeg>.from(currentGame.legs)..removeAt(legIndex);
    await _service.updateLegs(game: currentGame, legs: updatedLegs);
  }

  void _confirmFinishGame(DartsGame currentGame) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Match beenden?'),
        content: const Text(
            'Möchtest du dieses Match vorzeitig abschließen? Danach können keine Legs mehr eingetragen werden.'),
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

  void _confirmDiscardGame(DartsGame currentGame) async {
    final bool isFinished = currentGame.status == 'finished';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFinished ? 'Match löschen?' : 'Match verwerfen?'),
        content: Text(
          isFinished
              ? 'Möchtest du dieses beendete Match wirklich aus der Historie löschen?'
              : 'Möchtest du dieses laufende Match wirklich abbrechen und löschen? Alle Legs werden unwiderruflich gelöscht.',
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

    return StreamBuilder<DartsGame?>(
      stream: _service.getGameStream(widget.game.id!),
      initialData: widget.game,
      builder: (context, snapshot) {
        final currentGame = snapshot.data ?? widget.game;
        return _buildScaffold(currentGame);
      },
    );
  }

  Widget _buildScaffold(DartsGame currentGame) {
    final bool isFinished = currentGame.status == 'finished';
    final int? winner = currentGame.winnerIndex;
    // Rückgängig ist erlaubt, solange nicht manuell beendet wurde
    final bool canUndo = currentGame.legs.isNotEmpty && (!isFinished || winner != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart'),
        centerTitle: true,
        actions: [
          if (canUndo)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Letztes Leg rückgängig',
              onPressed: () => _removeLeg(currentGame, currentGame.legs.length - 1),
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
            'First to ${currentGame.legsToWin} ${currentGame.legsToWin == 1 ? "Leg" : "Legs"}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            'Best of ${currentGame.legsToWin * 2 - 1}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Die beiden Spieler nebeneinander
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildPlayerCard(currentGame, 0, canAddLeg: !isFinished)),
                const SizedBox(width: 12),
                Expanded(child: _buildPlayerCard(currentGame, 1, canAddLeg: !isFinished)),
              ],
            ),
          ),

          const Divider(height: 32, thickness: 2),

          // Verlauf der Legs
          ..._buildHistory(currentGame, isFinished),
        ],
      ),
    );
  }

  Widget _buildWinnerBanner(DartsGame game, int winner) {
    final color = dartsPlayerColors[winner];
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
              '${game.playerNames[winner]} gewinnt!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Legs: ${game.legsWon.join(' : ')}',
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

  Widget _buildPlayerCard(DartsGame game, int playerIndex, {required bool canAddLeg}) {
    final color = dartsPlayerColors[playerIndex];
    final legs = game.legsWon[playerIndex];
    final name = playerIndex < game.playerNames.length
        ? game.playerNames[playerIndex]
        : 'Spieler ${playerIndex + 1}';

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
              name,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '$legs',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: legs > 0 ? Colors.white : Colors.grey,
              ),
            ),
            // Fortschritt bis zum Sieg
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: List.generate(game.legsToWin, (i) {
                final won = i < legs;
                return Icon(
                  won ? Icons.circle : Icons.circle_outlined,
                  size: 12,
                  color: won ? color : Colors.grey,
                );
              }),
            ),
            const Spacer(),
            if (canAddLeg) ...[
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
                  onPressed: () => _addLeg(game, playerIndex),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Leg',
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

  List<Widget> _buildHistory(DartsGame game, bool isFinished) {
    final counted = game.countedLegs;
    if (counted.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'Noch keine Legs gespielt.\nTippe auf „+ Leg“ beim Gewinner des Legs.',
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
      final leg = counted[i];
      running[leg.winnerIndex]++;
      final color = dartsPlayerColors[leg.winnerIndex];

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
          'Leg ${i + 1}: ${game.playerNames[leg.winnerIndex]}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text('Stand ${running.join(' : ')}'),
        trailing: isFinished
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                tooltip: 'Leg löschen',
                onPressed: () => _removeLeg(game, i),
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
