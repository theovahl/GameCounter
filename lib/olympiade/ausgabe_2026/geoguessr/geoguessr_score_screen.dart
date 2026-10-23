import 'package:flutter/material.dart';
import 'geoguessr_models.dart';
import 'geoguessr_service.dart';

const List<Color> geoguessrTeamColors = [Colors.lightGreenAccent, Colors.purpleAccent];

class GeoguessrScoreScreen extends StatefulWidget {
  final GeoguessrGame game;
  final GeoguessrService? service; // Optional, z.B. für Spiele einer WG Olympiade

  const GeoguessrScoreScreen({super.key, required this.game, this.service});

  @override
  State<GeoguessrScoreScreen> createState() => _GeoguessrScoreScreenState();
}

class _GeoguessrScoreScreenState extends State<GeoguessrScoreScreen> {
  late final GeoguessrService _service = widget.service ?? GeoguessrService();

  Future<void> _addWin(GeoguessrGame currentGame, int teamIndex) async {
    if (currentGame.id == null) return;
    final updatedRounds = List<GeoguessrRound>.from(currentGame.rounds)
      ..add(GeoguessrRound(
        winnerIndex: teamIndex,
        // Runde zählt zur aktuell offenen Stufe
        stageIndex: currentGame.currentStageIndex ?? currentGame.stages.length - 1,
        timestamp: DateTime.now(),
      ));
    await _service.updateRounds(game: currentGame, rounds: updatedRounds);
  }

  Future<void> _removeRound(GeoguessrGame currentGame, int roundIndex) async {
    if (currentGame.id == null) return;
    final updatedRounds = List<GeoguessrRound>.from(currentGame.rounds)..removeAt(roundIndex);
    await _service.updateRounds(game: currentGame, rounds: updatedRounds);
  }

  void _confirmFinishGame(GeoguessrGame currentGame) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spiel beenden?'),
        content: const Text(
            'Möchtest du dieses Spiel vorzeitig abschließen? Danach können keine Siege mehr eingetragen werden.'),
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

  void _confirmDiscardGame(GeoguessrGame currentGame) async {
    final bool isFinished = currentGame.status == 'finished';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFinished ? 'Spiel löschen?' : 'Spiel verwerfen?'),
        content: Text(
          isFinished
              ? 'Möchtest du dieses beendete Spiel wirklich aus der Historie löschen?'
              : 'Möchtest du dieses laufende Spiel wirklich abbrechen und löschen? Alle Siege werden unwiderruflich gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isFinished ? 'Löschen' : 'Spiel verwerfen',
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
              isFinished ? 'Das Spiel wurde gelöscht.' : 'Das Spiel wurde abgebrochen und verworfen.',
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

    return StreamBuilder<GeoguessrGame?>(
      stream: _service.getGameStream(widget.game.id!),
      initialData: widget.game,
      builder: (context, snapshot) {
        final currentGame = snapshot.data ?? widget.game;
        return _buildScaffold(currentGame);
      },
    );
  }

  Widget _buildScaffold(GeoguessrGame currentGame) {
    final bool isFinished = currentGame.status == 'finished';
    final int? winner = currentGame.winnerIndex;
    // Rückgängig ist erlaubt, solange nicht manuell beendet wurde
    final bool canUndo = currentGame.rounds.isNotEmpty && (!isFinished || winner != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoGuessr'),
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
                      Text('Spiel beenden'),
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
                      isFinished ? 'Spiel löschen' : 'Spiel verwerfen',
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
            _buildFinishedBanner(currentGame),

          _buildStageOverview(currentGame, isFinished),
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

  Widget _buildWinnerBanner(GeoguessrGame game, int winner) {
    final color = geoguessrTeamColors[winner];
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
              'Runden gesamt: ${game.wins.join(' : ')}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedBanner(GeoguessrGame game) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.flag, size: 18, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          Text(
            game.isComplete
                ? 'Unentschieden – ${game.wins.join(' : ')} Runden'
                : 'Dieses Spiel wurde vorzeitig beendet',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(GeoguessrGame game, int teamIndex, {required bool canAddWin}) {
    final color = geoguessrTeamColors[teamIndex];
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
            const Text('Runden gesamt', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                    'Runde',
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

  // Aktuelle Stufe mit Zwischenstand und Übersicht aller Stufen
  Widget _buildStageOverview(GeoguessrGame game, bool isFinished) {
    final current = isFinished ? null : game.currentStageIndex;

    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (current != null) ...[
              Text(
                'Stufe ${current + 1} von ${game.stages.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              Text(
                game.stages[current].title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (game.stages[current].details.isNotEmpty)
                Text(
                  game.stages[current].details,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 10),
            ],
            // Alle Stufen mit Stand
            ...List.generate(game.stages.length, (i) {
              final stage = game.stages[i];
              final won = game.stageWins(i);
              final done = game.isStageDone(i);
              final stageWinner = done ? (won[0] > won[1] ? 0 : 1) : null;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle : (i == current ? Icons.play_circle : Icons.radio_button_unchecked),
                      size: 18,
                      color: done
                          ? geoguessrTeamColors[stageWinner!]
                          : (i == current ? Colors.amberAccent : Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${stage.title} (BO${stage.winsNeeded * 2 - 1})',
                        style: TextStyle(fontWeight: i == current ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                    Text(
                      won.join(' : '),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            const Text(
              'Gezählt werden alle gewonnenen Runden.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHistory(GeoguessrGame game, bool isFinished) {
    final counted = game.countedRounds;
    if (counted.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'Noch keine Runden gespielt.\nTippe nach jeder Runde auf „+ Runde“ beim Gewinnerteam.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }

    final widgets = <Widget>[
      const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text('Verlauf', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    ];

    // Neueste Stufe zuerst, darin neueste Runde zuerst
    for (int s = game.stages.length - 1; s >= 0; s--) {
      final stageRounds = counted.where((r) => r.stageIndex == s).toList();
      if (stageRounds.isEmpty) continue;

      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2, left: 4),
        child: Text(
          'Stufe ${s + 1}: ${game.stages[s].title}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
        ),
      ));

      final running = [0, 0];
      final rows = <Widget>[];
      for (int n = 0; n < stageRounds.length; n++) {
        final round = stageRounds[n];
        running[round.winnerIndex]++;
        final color = geoguessrTeamColors[round.winnerIndex];
        // Index in der vollständigen Liste, damit das Löschen die richtige Runde trifft
        final roundIndex = game.rounds.indexOf(round);

        rows.add(ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.25),
            child: Text(
              '${n + 1}',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            'Runde ${n + 1}: ${game.teams[round.winnerIndex].name}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text('Stand ${running.join(' : ')}'),
          trailing: isFinished
              ? null
              : IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: 'Runde löschen',
                  onPressed: () => _removeRound(game, roundIndex),
                ),
        ));
      }
      widgets.addAll(rows.reversed);
    }
    return widgets;
  }
}
