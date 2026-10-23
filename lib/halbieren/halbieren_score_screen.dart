import 'dart:async';
import 'package:flutter/material.dart';
import 'halbieren_models.dart';
import 'halbieren_service.dart';

const List<Color> halbierenTeamColors = [Colors.orangeAccent, Colors.tealAccent];

/// Spielbildschirm "Das Große Teilen"
class HalbierenScoreScreen extends StatefulWidget {
  final HalbierenGame game;
  final HalbierenService? service; // Optional, z.B. für Spiele einer WG Olympiade

  const HalbierenScoreScreen({super.key, required this.game, this.service});

  @override
  State<HalbierenScoreScreen> createState() => _HalbierenScoreScreenState();
}

class _HalbierenScoreScreenState extends State<HalbierenScoreScreen> {
  late final HalbierenService _service = widget.service ?? HalbierenService();

  // Eingaben für das aktuelle Lebensmittel (pro WG)
  int? _formFood;
  final List<TextEditingController> _deviationControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  final List<String?> _cutters = [null, null];

  // Countdown pro Lebensmittel (nur lokal auf diesem Gerät)
  Timer? _ticker;
  int _remainingSeconds = 0;
  bool _timerRunning = false;

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in _deviationControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Timer ---

  void _startTimer() {
    if (_remainingSeconds <= 0) return;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _remainingSeconds = 0;
          _timerRunning = false;
          _ticker?.cancel();
        }
      });
    });
    setState(() => _timerRunning = true);
  }

  void _pauseTimer() {
    _ticker?.cancel();
    setState(() => _timerRunning = false);
  }

  void _resetTimer(HalbierenGame game) {
    _ticker?.cancel();
    setState(() {
      _timerRunning = false;
      _remainingSeconds = game.secondsPerFood;
    });
  }

  /// Setzt Eingaben und Timer zurück, sobald ein neues Lebensmittel dran ist
  void _prepareForm(HalbierenGame game, int? foodIndex) {
    if (_formFood == foodIndex) return;
    _formFood = foodIndex;
    _ticker?.cancel();
    _timerRunning = false;
    _remainingSeconds = game.secondsPerFood;
    if (foodIndex == null) return;

    final food = game.foods[foodIndex];
    for (int t = 0; t < 2; t++) {
      final existing = game.entryFor(foodIndex, t);
      _deviationControllers[t].text = existing != null ? _formatInput(existing.deviation) : '';
      // Vorschlag: erste Person, die in diesem Akt noch nicht zerteilt hat
      final done = game.cuttersInAct(food.act, t);
      final team = game.teams[t];
      _cutters[t] = existing?.cutterUid ??
          team.playerUids.firstWhere((uid) => !done.contains(uid),
              orElse: () => team.playerUids.isNotEmpty ? team.playerUids.first : '');
      if (_cutters[t] == '') _cutters[t] = null;
    }
  }

  String _formatInput(double value) => value.toString().replaceAll('.', ',');

  double? _parseDeviation(String text) {
    final cleaned = text.replaceAll('%', '').replaceAll(',', '.').trim();
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return value;
  }

  // --- Speichern ---

  Future<void> _saveEntry(
    HalbierenGame game,
    int foodIndex,
    int teamIndex,
    double deviation,
    String? cutterUid,
  ) async {
    if (game.id == null) return;
    final team = game.teams[teamIndex];
    final cutterPos = cutterUid != null ? team.playerUids.indexOf(cutterUid) : -1;

    final updated = game.entries
        .where((e) => !(e.foodIndex == foodIndex && e.teamIndex == teamIndex))
        .toList()
      ..add(TeilenEntry(
        foodIndex: foodIndex,
        teamIndex: teamIndex,
        deviation: deviation,
        cutterUid: cutterUid,
        cutterName: cutterPos >= 0 ? team.playerNames[cutterPos] : null,
        timestamp: DateTime.now(),
      ));
    await _service.updateEntries(game: game, entries: updated);
  }

  Future<void> _deleteEntry(HalbierenGame game, int foodIndex, int teamIndex) async {
    if (game.id == null) return;
    final updated = game.entries
        .where((e) => !(e.foodIndex == foodIndex && e.teamIndex == teamIndex))
        .toList();
    await _service.updateEntries(game: game, entries: updated);
  }

  void _submitCurrent(HalbierenGame game, int foodIndex, int teamIndex) {
    final value = _parseDeviation(_deviationControllers[teamIndex].text);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte eine gültige Abweichung in Prozent eintragen, z.B. 3,5'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    _saveEntry(game, foodIndex, teamIndex, value, _cutters[teamIndex]);
  }

  void _showEditDialog(HalbierenGame game, int foodIndex, int teamIndex) {
    final existing = game.entryFor(foodIndex, teamIndex);
    final team = game.teams[teamIndex];
    final color = halbierenTeamColors[teamIndex];
    final controller = TextEditingController(
      text: existing != null ? _formatInput(existing.deviation) : '',
    );
    String? cutter = existing?.cutterUid;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            '${game.foods[foodIndex].name} – ${team.name}',
            style: TextStyle(color: color),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Wer hat zerteilt?', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: List.generate(team.playerUids.length, (p) {
                  final uid = team.playerUids[p];
                  return ChoiceChip(
                    label: Text(team.playerNames[p]),
                    selected: cutter == uid,
                    selectedColor: color.withValues(alpha: 0.3),
                    onSelected: (_) => setDialogState(() => cutter = uid),
                  );
                }),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: existing == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Abweichung in %',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _deleteEntry(game, foodIndex, teamIndex);
                },
                child: const Text('Löschen', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = _parseDeviation(controller.text);
                if (value == null) return;
                Navigator.pop(dialogContext);
                _saveEntry(game, foodIndex, teamIndex, value, cutter);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmFinishGame(HalbierenGame game) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spiel beenden?'),
        content: const Text(
          'Möchtest du das Spiel vorzeitig beenden? Es zählt die bisherige Gesamtabweichung.',
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

  void _confirmDiscardGame(HalbierenGame game) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spiel verwerfen?'),
        content: const Text('Alle eingetragenen Ergebnisse werden unwiderruflich gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verwerfen', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true && game.id != null) {
      await _service.deleteGame(game.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    if (widget.game.id == null) return _buildScaffold(widget.game);

    return StreamBuilder<HalbierenGame?>(
      stream: _service.getGameStream(widget.game.id!),
      initialData: widget.game,
      builder: (context, snapshot) => _buildScaffold(snapshot.data ?? widget.game),
    );
  }

  Widget _buildScaffold(HalbierenGame game) {
    final bool isFinished = game.status == 'finished';
    final int? current = isFinished ? null : game.currentFoodIndex;
    _prepareForm(game, current);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Das Große Teilen'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'finish') _confirmFinishGame(game);
              if (value == 'discard') _confirmDiscardGame(game);
            },
            itemBuilder: (context) => [
              if (!isFinished)
                const PopupMenuItem(value: 'finish', child: Text('Spiel beenden')),
              const PopupMenuItem(
                value: 'discard',
                child: Text('Spiel verwerfen', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isFinished) _buildResultBanner(game),
          _buildTotals(game),
          const SizedBox(height: 16),
          if (current != null) _buildCurrentFood(game, current),
          const SizedBox(height: 16),
          ..._buildOverview(game, isFinished),
        ],
      ),
    );
  }

  Widget _buildResultBanner(HalbierenGame game) {
    final totals = game.totals;
    final winner = totals[0] < totals[1] ? 0 : (totals[1] < totals[0] ? 1 : null);
    final color = winner != null ? halbierenTeamColors[winner] : Colors.white70;
    return Card(
      color: color.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color, width: 2),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 40, color: color),
            const SizedBox(height: 6),
            Text(
              winner != null ? '${game.teams[winner].name} gewinnt!' : 'Unentschieden!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
            Text(
              'Gesamtabweichung: ${formatTeilenPercent(totals[0])} : ${formatTeilenPercent(totals[1])}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (!game.isComplete)
              Text(
                'Vorzeitig beendet nach ${game.doneCount} von ${game.foods.length} Lebensmitteln',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals(HalbierenGame game) {
    final totals = game.totals;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(2, (t) {
          final color = halbierenTeamColors[t];
          final ahead = totals[t] < totals[1 - t] && game.entries.isNotEmpty;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: t == 0 ? 0 : 6, right: t == 0 ? 6 : 0),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        game.teams[t].name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        game.teams[t].playerNames.join(', '),
                        style: const TextStyle(fontSize: 11, color: Colors.white60),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatTeilenPercent(totals[t]),
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                      ),
                      const Text('Abweichung gesamt', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      if (ahead) ...[
                        const SizedBox(height: 4),
                        Text('▲ genauer', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentFood(HalbierenGame game, int foodIndex) {
    final food = game.foods[foodIndex];
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeUp = _remainingSeconds == 0;
    final timerColor = timeUp
        ? Colors.redAccent
        : (_remainingSeconds <= 30 ? Colors.orangeAccent : Colors.white);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.amberAccent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${food.actTitle} • Lebensmittel ${foodIndex + 1} von ${game.foods.length}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              food.name,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (food.actNote != null) ...[
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    food.actNote!,
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Countdown
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, color: timerColor),
                const SizedBox(width: 8),
                Text(
                  timeUp ? 'Zeit abgelaufen!' : '$minutes:${seconds.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: timeUp ? 22 : 34,
                    fontWeight: FontWeight.bold,
                    color: timerColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_timerRunning ? Icons.pause_circle : Icons.play_circle, size: 32),
                  tooltip: _timerRunning ? 'Pause' : 'Start',
                  onPressed: timeUp ? null : (_timerRunning ? _pauseTimer : _startTimer),
                ),
                IconButton(
                  icon: const Icon(Icons.replay),
                  tooltip: 'Zurücksetzen',
                  onPressed: () => _resetTimer(game),
                ),
              ],
            ),
            const Divider(height: 24),

            // Eingabe pro WG
            ...List.generate(2, (t) => _buildTeamInput(game, foodIndex, t)),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamInput(HalbierenGame game, int foodIndex, int teamIndex) {
    final team = game.teams[teamIndex];
    final color = halbierenTeamColors[teamIndex];
    final existing = game.entryFor(foodIndex, teamIndex);
    final alreadyCut = game.cuttersInAct(game.foods[foodIndex].act, teamIndex);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(team.name, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
              const Spacer(),
              if (existing != null)
                Text(
                  '✓ ${formatTeilenPercent(existing.deviation)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Wer zerteilt? Wer im Akt schon dran war, ist markiert
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: List.generate(team.playerUids.length, (p) {
              final uid = team.playerUids[p];
              final done = alreadyCut.contains(uid) && existing?.cutterUid != uid;
              return ChoiceChip(
                label: Text(done ? '${team.playerNames[p]} ✓' : team.playerNames[p]),
                selected: _cutters[teamIndex] == uid,
                selectedColor: color.withValues(alpha: 0.3),
                labelStyle: TextStyle(color: done ? Colors.grey : null),
                onSelected: (_) => setState(() => _cutters[teamIndex] = uid),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _deviationControllers[teamIndex],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Abweichung in %',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submitCurrent(game, foodIndex, teamIndex),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.2),
                  foregroundColor: color,
                  side: BorderSide(color: color),
                ),
                onPressed: () => _submitCurrent(game, foodIndex, teamIndex),
                child: Text(existing != null ? 'Ändern' : 'Eintragen'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOverview(HalbierenGame game, bool isFinished) {
    final widgets = <Widget>[];
    int? lastAct;
    for (int i = 0; i < game.foods.length; i++) {
      final food = game.foods[i];
      if (food.act != lastAct) {
        lastAct = food.act;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4, left: 4),
          child: Text(
            food.actNote != null ? '${food.actTitle} – ${food.actNote}' : food.actTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ));
      }

      final entries = [game.entryFor(i, 0), game.entryFor(i, 1)];
      final better = entries[0] != null && entries[1] != null
          ? (entries[0]!.deviation < entries[1]!.deviation
              ? 0
              : (entries[1]!.deviation < entries[0]!.deviation ? 1 : null))
          : null;

      widgets.add(Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(food.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              ...List.generate(2, (t) {
                final entry = entries[t];
                final color = halbierenTeamColors[t];
                return Expanded(
                  flex: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: isFinished ? null : () => _showEditDialog(game, i, t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            entry != null ? formatTeilenPercent(entry.deviation) : '–',
                            style: TextStyle(
                              color: entry != null ? color : Colors.grey,
                              fontWeight: better == t ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (entry?.cutterName != null)
                            Text(
                              entry!.cutterName!,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ));
    }
    return widgets;
  }
}
