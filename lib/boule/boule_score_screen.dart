import 'package:flutter/material.dart';
import 'boule_models.dart';
import 'boule_service.dart';

const List<Color> bouleTeamColors = [
  Colors.lightBlueAccent,
  Colors.redAccent,
  Colors.greenAccent,
  Colors.amberAccent,
  Colors.purpleAccent,
  Colors.orangeAccent,
];

Color bouleTeamColor(int index) => bouleTeamColors[index % bouleTeamColors.length];

class BouleScoreScreen extends StatefulWidget {
  final BouleGame game;
  final BouleService? service; // Optional, z.B. für Spiele einer WG Olympiade

  const BouleScoreScreen({super.key, required this.game, this.service});

  @override
  State<BouleScoreScreen> createState() => _BouleScoreScreenState();
}

class _BouleScoreScreenState extends State<BouleScoreScreen> {
  late final BouleService _service = widget.service ?? BouleService();

  Future<void> _addEnd(BouleGame currentGame, int teamIndex, int points) async {
    if (currentGame.id == null || points <= 0) return;
    final updatedEnds = List<BouleEnd>.from(currentGame.ends)
      ..add(BouleEnd(teamIndex: teamIndex, points: points, timestamp: DateTime.now()));
    await _service.updateEnds(game: currentGame, ends: updatedEnds);
  }

  Future<void> _removeEnd(BouleGame currentGame, int endIndex) async {
    if (currentGame.id == null) return;
    final updatedEnds = List<BouleEnd>.from(currentGame.ends)..removeAt(endIndex);
    await _service.updateEnds(game: currentGame, ends: updatedEnds);
  }

  void _showAddPointsSheet(BouleGame currentGame, int teamIndex) {
    final team = currentGame.teams[teamIndex];
    final color = bouleTeamColor(teamIndex);
    final customController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        Future<void> submit(int points) async {
          Navigator.pop(sheetContext);
          await _addEnd(currentGame, teamIndex, points);
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            top: 20,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Punkte für ${team.name}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                team.playerNames.join(', '),
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Schnellauswahl 1–6 Punkte
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: List.generate(6, (i) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.withValues(alpha: 0.2),
                      foregroundColor: color,
                      side: BorderSide(color: color, width: 1.5),
                    ),
                    onPressed: () => submit(i + 1),
                    child: Text(
                      '+${i + 1}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Freie Eingabe für andere Punktzahlen
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: customController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Andere Punktzahl',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: () {
                      final points = int.tryParse(customController.text.trim()) ?? 0;
                      if (points > 0) submit(points);
                    },
                    icon: const Icon(Icons.check),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _confirmFinishGame(BouleGame currentGame) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spiel beenden?'),
        content: const Text(
            'Möchtest du dieses Spiel vorzeitig abschließen? Danach können keine Punkte mehr eingetragen werden.'),
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

  void _confirmDiscardGame(BouleGame currentGame) async {
    final bool isFinished = currentGame.status == 'finished';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFinished ? 'Spiel löschen?' : 'Spiel verwerfen?'),
        content: Text(
          isFinished
              ? 'Möchtest du dieses beendete Spiel wirklich aus der Historie löschen?'
              : 'Möchtest du dieses laufende Spiel wirklich abbrechen und löschen? Alle Punkte werden unwiderruflich gelöscht.',
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

    return StreamBuilder<BouleGame?>(
      stream: _service.getGameStream(widget.game.id!),
      initialData: widget.game,
      builder: (context, snapshot) {
        final currentGame = snapshot.data ?? widget.game;
        return _buildScaffold(currentGame);
      },
    );
  }

  Widget _buildScaffold(BouleGame currentGame) {
    final bool isFinished = currentGame.status == 'finished';
    final int? winner = currentGame.winnerTeam;
    // Rückgängig ist erlaubt, solange nicht manuell beendet wurde
    final bool canUndo = currentGame.ends.isNotEmpty && (!isFinished || winner != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boule'),
        centerTitle: true,
        actions: [
          if (canUndo)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Letzte Aufnahme rückgängig',
              onPressed: () => _removeEnd(currentGame, currentGame.ends.length - 1),
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
            _buildFinishedBanner(),

          // Modus-Info
          Text(
            winner != null
                ? 'Endstand nach ${currentGame.sets.length} ${currentGame.sets.length == 1 ? "Satz" : "Sätzen"}'
                : 'Satz ${currentGame.currentSet.setNumber} • bis ${currentGame.pointsPerSet} Punkte',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            currentGame.setsToWin == 1
                ? '1 Gewinnsatz'
                : '${currentGame.setsToWin} Gewinnsätze',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Team-Karten mit aktuellem Stand
          ...List.generate(currentGame.teams.length, (i) {
            return _buildTeamCard(currentGame, i, canAddPoints: !isFinished);
          }),

          if (!isFinished)
            const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text(
                'Tippe auf ein Team, um Punkte einzutragen.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),

          const Divider(height: 32, thickness: 2),

          // Verlauf aller Sätze und Aufnahmen
          ..._buildHistory(currentGame, isFinished),
        ],
      ),
    );
  }

  Widget _buildWinnerBanner(BouleGame game, int winner) {
    final color = bouleTeamColor(winner);
    final setsWon = game.setsWon;
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
            ),
            Text(
              game.teams[winner].playerNames.join(', '),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            if (game.setsToWin > 1) ...[
              const SizedBox(height: 6),
              Text(
                'Sätze: ${setsWon.join(' : ')}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
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
            'Dieses Spiel wurde vorzeitig beendet',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(BouleGame game, int teamIndex, {required bool canAddPoints}) {
    final team = game.teams[teamIndex];
    final color = bouleTeamColor(teamIndex);
    final score = game.currentSet.scores[teamIndex];
    final setsWon = game.setsWon[teamIndex];

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 5)),
        ),
        child: InkWell(
          onTap: canAddPoints ? () => _showAddPointsSheet(game, teamIndex) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        team.playerNames.join(', '),
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      if (game.setsToWin > 1) ...[
                        const SizedBox(height: 8),
                        // Gewonnene Sätze als Punkte
                        Row(
                          children: List.generate(game.setsToWin, (i) {
                            final won = i < setsWon;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: Icon(
                                won ? Icons.circle : Icons.circle_outlined,
                                size: 14,
                                color: won ? color : Colors.grey,
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: score > 0 ? Colors.white : Colors.grey,
                  ),
                ),
                if (canAddPoints) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.add_circle, color: color, size: 28),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHistory(BouleGame game, bool isFinished) {
    if (game.ends.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'Noch keine Aufnahmen gespielt.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    // Neueste Sätze zuerst
    for (final set in game.sets.reversed) {
      if (set.endIndices.isEmpty) continue;

      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Text(
              'Satz ${set.setNumber}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            if (set.isFinished)
              Text(
                '${game.teams[set.winnerTeam!].name} gewinnt ${set.scores.join(' : ')}',
                style: TextStyle(color: bouleTeamColor(set.winnerTeam!), fontSize: 13),
              )
            else
              const Text('läuft', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ));

      // Zwischenstände innerhalb des Satzes berechnen
      final running = List<int>.filled(game.teams.length, 0);
      final rows = <Widget>[];
      for (int n = 0; n < set.endIndices.length; n++) {
        final endIndex = set.endIndices[n];
        final end = game.ends[endIndex];
        running[end.teamIndex] += end.points;
        final color = bouleTeamColor(end.teamIndex);

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
            '${game.teams[end.teamIndex].name}  +${end.points}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text('Stand ${running.join(' : ')}'),
          trailing: isFinished
              ? null
              : IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: 'Aufnahme löschen',
                  onPressed: () => _removeEnd(game, endIndex),
                ),
        ));
      }
      widgets.addAll(rows.reversed);
    }
    return widgets;
  }
}
