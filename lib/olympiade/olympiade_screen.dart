import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_counter/auth_service.dart';
import 'package:game_counter/mariokart/mariokart_data.dart';
import 'olympiade_models.dart';
import 'olympiade_service.dart';
import 'olympiade_disciplines.dart';
import 'olympiade_scoreboard.dart';
import 'olympiade_info_widgets.dart';

class OlympiadeScreen extends StatefulWidget {
  final OlympiadeGame olympiade;

  const OlympiadeScreen({super.key, required this.olympiade});

  @override
  State<OlympiadeScreen> createState() => _OlympiadeScreenState();
}

class _OlympiadeScreenState extends State<OlympiadeScreen> {
  final OlympiadeService _service = OlympiadeService();
  final AuthService _authService = AuthService();

  late OlympiadeGame _latest = widget.olympiade;
  bool _initialSyncStarted = false;
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    if (widget.olympiade.id == null) {
      return _buildScaffold(widget.olympiade);
    }

    return StreamBuilder<OlympiadeGame?>(
      stream: _service.getOlympiadeStream(widget.olympiade.id!),
      initialData: widget.olympiade,
      builder: (context, snapshot) {
        final olympiade = snapshot.data ?? _latest;
        _latest = olympiade;

        // Beim Öffnen einmal die Ergebnisse aus den verknüpften Spielen übernehmen
        if (!_initialSyncStarted && snapshot.data != null) {
          _initialSyncStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _syncResults());
        }
        return _buildScaffold(olympiade);
      },
    );
  }

  // --- Ergebnisse synchronisieren ---

  /// Liest alle verknüpften Spiele und überträgt deren Sieger in die Olympiade.
  Future<void> _syncResults() async {
    if (_syncing || _latest.id == null) return;
    _syncing = true;
    if (mounted) setState(() {});

    try {
      var olympiade = _latest;
      for (final discipline in olympiade.disciplines) {
        final current = olympiade.resultFor(discipline);
        if (current.gameId == null) continue;

        OlympiadeResult updated;
        if (olympiadeDiscipline(discipline).multiGame) {
          // Dart/Bierpong: Legs bzw. Siege aller Spiele summieren, entschieden wird erst per "Beenden"
          if (current.isDone) continue;
          updated = await olympiadeMultiGameResult(discipline, current, olympiade);
        } else {
          final game = await loadOlympiadeDisciplineGame(discipline, current.gameId!, olympiade);
          updated = game == null
              // Spiel wurde im Modus gelöscht -> Disziplin wieder offen
              ? const OlympiadeResult()
              : OlympiadeResult(
                  gameIds: current.gameIds,
                  winnerWg: olympiadeWinnerFromGame(game, olympiade),
                );
        }

        if (!updated.sameAs(current)) {
          await _service.setResult(olympiade: olympiade, discipline: discipline, result: updated);
          olympiade = olympiade.copyWithResult(discipline, updated);
        }
      }
    } finally {
      _syncing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _openGame(String discipline, String gameId) async {
    final game = await loadOlympiadeDisciplineGame(discipline, gameId, _latest);
    if (!mounted) return;

    final screen = game != null ? olympiadeScoreScreenFor(game, _latest) : null;
    if (screen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Das Spiel wurde nicht gefunden und wird zurückgesetzt.')),
      );
      await _syncResults();
      return;
    }

    await Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    await _syncResults();
  }

  // --- Aktionen ---

  void _showLiveLinkDialog(String olympiadeId) {
    final url = olympiadeLiveUrl(olympiadeId);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.live_tv, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Live für Zuschauer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mit diesem Link können alle den aktuellen Punktestand und die Ergebnisse '
              'live im Browser verfolgen – ganz ohne App und Anmeldung.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(url, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Wer den Link hat, sieht die Namen aller Teilnehmer.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Schließen'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Live-Link kopiert – jetzt z.B. in WhatsApp einfügen.')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Link kopieren'),
          ),
        ],
      ),
    );
  }

  void _showStartSheet(OlympiadeGame olympiade, String discipline) async {
    final gameId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _StartDisciplineSheet(
        olympiade: olympiade,
        discipline: discipline,
        createdBy: _authService.currentUserId ?? olympiade.createdBy,
      ),
    );

    if (gameId != null && mounted) {
      await _openGame(discipline, gameId);
    }
  }

  void _showRulesSheet(OlympiadeGame olympiade, String discipline) {
    final rules = olympiade.edition.rulesFor(discipline);
    if (rules == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          child: OlympiadeRuleCard(section: rules),
        ),
      ),
    );
  }

  void _showManualResultDialog(OlympiadeGame olympiade, String discipline) async {
    final info = olympiadeDiscipline(discipline);
    final result = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Ergebnis ${info.name}'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Lege den Sieger selbst fest. Ein verknüpftes Spiel wird dafür nicht mehr ausgewertet.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          ...List.generate(2, (i) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: olympiadeWgColors[i]),
                  const SizedBox(width: 12),
                  Text(olympiade.wgs[i].name, style: const TextStyle(fontSize: 16)),
                ],
              ),
            );
          }),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, olympiadeDraw),
            child: const Row(
              children: [
                Icon(Icons.handshake_outlined, color: Colors.grey),
                SizedBox(width: 12),
                Text('Unentschieden', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      await _service.setResult(
        olympiade: olympiade,
        discipline: discipline,
        result: OlympiadeResult(winnerWg: result),
      );
    }
  }

  /// Beendet eine Mehrfach-Disziplin (Dart/Bierpong): Sieger ist die WG mit mehr Legs bzw. Siegen.
  void _confirmFinishMultiGame(OlympiadeGame olympiade, String discipline) async {
    final info = olympiadeDiscipline(discipline);
    // Vor dem Beenden den aktuellen Stand aus allen Spielen holen
    final current = await olympiadeMultiGameResult(discipline, olympiade.resultFor(discipline), olympiade);
    if (!mounted) return;

    final winner = olympiadeLeader(current.tally);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${info.name} beenden?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${info.tallyLabel}: ${olympiade.wgs[0].name} ${current.tally[0]} : '
              '${current.tally[1]} ${olympiade.wgs[1].name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              winner == olympiadeDraw
                  ? 'Gleichstand – die Disziplin endet unentschieden (je ½ Punkt).'
                  : '${olympiade.wgs[winner].name} gewinnt ${info.name}.',
            ),
            if (current.lastGameActive) ...[
              const SizedBox(height: 8),
              const Text(
                'Achtung: Das letzte Spiel läuft noch. Es zählt der aktuelle Stand.',
                style: TextStyle(color: Colors.amberAccent, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Weiterspielen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('${info.name} beenden', style: const TextStyle(color: Colors.amberAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.setResult(
        olympiade: olympiade,
        discipline: discipline,
        result: OlympiadeResult(
          gameIds: current.gameIds,
          tally: current.tally,
          winnerWg: winner,
        ),
      );
    }
  }

  void _confirmResetDiscipline(OlympiadeGame olympiade, String discipline) async {
    final info = olympiadeDiscipline(discipline);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${info.name} zurücksetzen?'),
        content: const Text(
          'Das Ergebnis wird entfernt und die Disziplin kann neu gestartet werden. '
          'Bereits gespielte Spiele zählen dann nicht mehr.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Zurücksetzen', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.setResult(
        olympiade: olympiade,
        discipline: discipline,
        result: const OlympiadeResult(),
      );
    }
  }

  void _confirmFinish(OlympiadeGame olympiade) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Olympiade beenden?'),
        content: const Text(
          'Offene Disziplinen werden nicht mehr gespielt. Es zählt der aktuelle Punktestand.',
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

    if (confirm == true && olympiade.id != null) {
      await _service.finishOlympiade(olympiade.id!);
    }
  }

  void _confirmDelete(OlympiadeGame olympiade) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Olympiade löschen?'),
        content: const Text(
          'Die Olympiade wird mit allen Ergebnissen und den darin gespielten Spielen gelöscht.',
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

    if (confirm == true && olympiade.id != null) {
      await _service.deleteOlympiade(olympiade.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Die Olympiade wurde gelöscht.')),
        );
      }
    }
  }

  // --- UI ---

  Widget _buildScaffold(OlympiadeGame olympiade) {
    final bool isFinished = olympiade.status == 'finished';

    final running = olympiade.disciplines.where((d) => olympiade.resultFor(d).isRunning).toList();
    final open = olympiade.disciplines.where((d) => olympiade.resultFor(d).isOpen).toList();
    final done = olympiade.disciplines.where((d) => olympiade.resultFor(d).isDone).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('WG Olympiade'),
            Text(
              olympiade.edition.label,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Regeln & Zeitplan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OlympiadeInfoScreen(
                  edition: olympiade.edition,
                  olympiade: olympiade,
                ),
              ),
            ),
          ),
          if (olympiade.id != null)
            IconButton(
              icon: const Icon(Icons.live_tv),
              tooltip: 'Live-Link für Zuschauer',
              onPressed: () => _showLiveLinkDialog(olympiade.id!),
            ),
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Ergebnisse aktualisieren',
            onPressed: _syncing ? null : _syncResults,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'finish') {
                _confirmFinish(olympiade);
              } else if (value == 'delete') {
                _confirmDelete(olympiade);
              }
            },
            itemBuilder: (context) => [
              if (!isFinished)
                const PopupMenuItem(
                  value: 'finish',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('Olympiade beenden'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Olympiade löschen', style: TextStyle(color: Colors.redAccent)),
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
          OlympiadeScoreboard(olympiade: olympiade),
          const SizedBox(height: 20),

          if (running.isNotEmpty) ...[
            _buildSectionHeader('Läuft gerade', Icons.play_circle_outline, running.length),
            ...running.map((d) => _buildDisciplineCard(olympiade, d, isFinished)),
            const SizedBox(height: 16),
          ],
          if (open.isNotEmpty) ...[
            _buildSectionHeader(
              isFinished ? 'Nicht gespielt' : 'Noch offen – was spielt ihr als Nächstes?',
              Icons.radio_button_unchecked,
              open.length,
            ),
            ...open.map((d) => _buildDisciplineCard(olympiade, d, isFinished)),
            const SizedBox(height: 16),
          ],
          if (done.isNotEmpty) ...[
            _buildSectionHeader('Abgeschlossen', Icons.check_circle_outline, done.length),
            ...done.map((d) => _buildDisciplineCard(olympiade, d, isFinished)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          Text('$count', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDisciplineCard(OlympiadeGame olympiade, String discipline, bool isFinished) {
    final info = olympiadeDiscipline(discipline);
    final result = olympiade.resultFor(discipline);
    final winner = result.winnerWg;

    // Zwischenstand bei Dart/Bierpong, z.B. "Legs 5 : 3 • 2 Spiele"
    final tallyText = info.multiGame
        ? olympiadeResultDetail(key: discipline, result: result, games: const [], olympiade: olympiade)
        : '';
    // Spielplan jeder gegen jeden komplett?
    final scheduleTotal = olympiadeRoundRobinTotal(olympiade, discipline);
    final allMatchesPlayed = scheduleTotal != null &&
        result.gameIds.length >= scheduleTotal &&
        !result.lastGameActive;

    Widget subtitle;
    Widget? action;
    // Zusätzliche Knopfzeile unter der Karte (Mehrfach-Disziplinen)
    Widget? bottomActions;
    if (result.isDone) {
      final suffix = info.multiGame && result.gameIds.isNotEmpty ? ' • $tallyText' : '';
      if (winner == olympiadeDraw) {
        subtitle = Text('Unentschieden • je ½ Punkt$suffix', style: const TextStyle(color: Colors.white70));
        action = const Icon(Icons.handshake_outlined, color: Colors.white70);
      } else {
        subtitle = Text(
          'Sieg für ${olympiade.wgs[winner!].name}$suffix',
          style: TextStyle(color: olympiadeWgColors[winner], fontWeight: FontWeight.w600),
        );
        action = Icon(Icons.emoji_events, color: olympiadeWgColors[winner]);
      }
    } else if (result.isRunning && info.multiGame) {
      subtitle = Text(
        result.lastGameActive
            ? '$tallyText • Spiel läuft'
            : (allMatchesPlayed ? '$tallyText • alle gespielt, jetzt beenden' : tallyText),
        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w600),
      );
      if (result.lastGameActive) {
        action = OutlinedButton(
          onPressed: () => _openGame(discipline, result.gameId!),
          child: const Text('Weiter'),
        );
      }
      if (!isFinished) {
        bottomActions = Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: result.lastGameActive ? null : () => _showStartSheet(olympiade, discipline),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nächstes Spiel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: info.color,
                    side: BorderSide(color: result.lastGameActive ? Colors.grey.shade700 : info.color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmFinishMultiGame(olympiade, discipline),
                  icon: const Icon(Icons.flag, size: 18),
                  label: Text('${info.name} beenden'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: info.color.withValues(alpha: 0.2),
                    foregroundColor: info.color,
                    side: BorderSide(color: info.color),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } else if (result.isRunning) {
      subtitle = const Text('Läuft – Ergebnis wird nach dem Spiel übernommen',
          style: TextStyle(color: Colors.amberAccent, fontSize: 12));
      action = OutlinedButton(
        onPressed: () => _openGame(discipline, result.gameId!),
        child: const Text('Weiter'),
      );
    } else {
      subtitle = Text(
        isFinished ? 'Nicht gespielt' : _kindDescription(info),
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      );
      action = isFinished
          ? null
          : ElevatedButton(
              onPressed: () => _showStartSheet(olympiade, discipline),
              style: ElevatedButton.styleFrom(
                backgroundColor: info.color.withValues(alpha: 0.2),
                foregroundColor: info.color,
                side: BorderSide(color: info.color),
              ),
              child: const Text('Starten'),
            );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: info.color, width: 4)),
        ),
        child: Column(
          children: [
            _buildDisciplineTile(
              olympiade: olympiade,
              discipline: discipline,
              info: info,
              result: result,
              subtitle: subtitle,
              action: action,
            ),
            ?bottomActions,
          ],
        ),
      ),
    );
  }

  Widget _buildDisciplineTile({
    required OlympiadeGame olympiade,
    required String discipline,
    required OlympiadeDiscipline info,
    required OlympiadeResult result,
    required Widget subtitle,
    required Widget? action,
  }) {
    return ListTile(
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: CircleAvatar(
            backgroundColor: info.color.withValues(alpha: 0.18),
            child: Icon(info.icon, color: info.color),
          ),
          title: Text(info.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: subtitle,
          onTap: result.isRunning && (!info.multiGame || result.lastGameActive)
              ? () => _openGame(discipline, result.gameId!)
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?action,
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'rules') {
                    _showRulesSheet(olympiade, discipline);
                  } else if (value == 'manual') {
                    _showManualResultDialog(olympiade, discipline);
                  } else if (value == 'reset') {
                    _confirmResetDiscipline(olympiade, discipline);
                  }
                },
                itemBuilder: (context) => [
                  if (olympiade.edition.rulesFor(discipline) != null)
                    const PopupMenuItem(
                      value: 'rules',
                      child: Row(
                        children: [
                          Icon(Icons.menu_book, size: 18),
                          SizedBox(width: 8),
                          Text('Regeln'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'manual',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Ergebnis festlegen'),
                      ],
                    ),
                  ),
                  if (!result.isOpen)
                    const PopupMenuItem(
                      value: 'reset',
                      child: Row(
                        children: [
                          Icon(Icons.restart_alt, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Zurücksetzen', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
    );
  }

  String _kindDescription(OlympiadeDiscipline info) {
    if (info.multiGame) {
      return '1 gegen 1 • mehrere Spiele, ${info.tallyLabel} pro WG zählen';
    }
    return switch (info.kind) {
      OlympiadeDisciplineKind.teams => 'WG gegen WG',
      OlympiadeDisciplineKind.duel => '1 gegen 1',
      OlympiadeDisciplineKind.drivers => 'Alle fahren, Ø-Punkte pro WG zählen',
    };
  }
}

// --- Dialog zum Starten einer Disziplin ---

class _StartDisciplineSheet extends StatefulWidget {
  final OlympiadeGame olympiade;
  final String discipline;
  final String createdBy;

  const _StartDisciplineSheet({
    required this.olympiade,
    required this.discipline,
    required this.createdBy,
  });

  @override
  State<_StartDisciplineSheet> createState() => _StartDisciplineSheetState();
}

class _StartDisciplineSheetState extends State<_StartDisciplineSheet> {
  final OlympiadeService _service = OlympiadeService();

  // Spielplan jeder gegen jeden (Dart, Bierpong): offene Duelle, null = lädt bzw. kein Spielplan
  List<OlympiadePairing>? _openPairings;
  late final bool _hasSchedule =
      olympiadeRoundRobinTotal(widget.olympiade, widget.discipline) != null;

  @override
  void initState() {
    super.initState();
    if (_hasSchedule) _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final games = await Future.wait(_current.gameIds.map(
      (id) => loadOlympiadeDisciplineGame(widget.discipline, id, widget.olympiade),
    ));
    final open = olympiadeOpenPairings(
      olympiadeRoundRobinPairings(widget.olympiade, widget.discipline),
      olympiadePlayedPairings(games),
    );
    if (!mounted) return;
    setState(() {
      _openPairings = open;
      // Nächstes offenes Duell vorschlagen
      if (open.isNotEmpty) _selectPairing(open.first);
    });
  }

  void _selectPairing(OlympiadePairing pairing) {
    _selected[0] = {pairing.a};
    _selected[1] = {pairing.b};
  }

  String _playerName(int wgIndex, String uid) {
    final wg = widget.olympiade.wgs[wgIndex];
    final i = wg.playerUids.indexOf(uid);
    return i >= 0 ? wg.playerNames[i] : '?';
  }

  late final OlympiadeDiscipline _info = olympiadeDiscipline(widget.discipline);
  late final bool _isDuel = _info.kind == OlympiadeDisciplineKind.duel;

  // Ausgewählte Teilnehmer pro WG (bei Duellen genau einer)
  late final List<Set<String>> _selected = List.generate(2, (i) {
    final uids = widget.olympiade.wgs[i].playerUids;
    return _isDuel ? {if (uids.isNotEmpty) uids.first} : uids.toSet();
  });

  late final Map<String, int> _settings = {
    for (final s in _info.settings)
      s.key: widget.olympiade.edition.settingDefault(widget.discipline, s.key) ?? s.defaultValue,
  };

  // Mario Kart: ausgewählte Strecken (Indizes in olympiadeMarioKartTracks, in Fahrreihenfolge)
  final List<int> _trackIndices = [];
  bool _isBusy = false;

  late final OlympiadeResult _current = widget.olympiade.resultFor(widget.discipline);

  // Ergebnis der Disziplin, nachdem ein weiteres Spiel angehängt wurde
  OlympiadeResult _withNewGame(String gameId, {int? bierpongWinner}) {
    if (!_info.multiGame) return OlympiadeResult(gameIds: [gameId]);
    final tally = List<int>.from(_current.tally);
    if (bierpongWinner != null) tally[bierpongWinner]++;
    return OlympiadeResult(
      gameIds: [..._current.gameIds, gameId],
      tally: tally,
      lastGameActive: bierpongWinner == null,
    );
  }

  List<List<String>> get _selectedUids => List.generate(2, (i) {
        return widget.olympiade.wgs[i].playerUids.where(_selected[i].contains).toList();
      });

  List<List<String>> get _selectedNames => List.generate(2, (i) {
        final wg = widget.olympiade.wgs[i];
        return [
          for (int p = 0; p < wg.playerUids.length; p++)
            if (_selected[i].contains(wg.playerUids[p])) wg.playerNames[p],
        ];
      });

  String? _validate() {
    for (int i = 0; i < 2; i++) {
      if (_selected[i].isEmpty) {
        return 'Wähle mindestens einen Teilnehmer für ${widget.olympiade.wgs[i].name}.';
      }
    }
    if (widget.discipline == 'mariokart' && _trackIndices.isEmpty) {
      return 'Wähle mindestens eine Strecke aus.';
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _start() async {
    final error = _validate();
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _isBusy = true);
    try {
      final gameId = await startOlympiadeDisciplineGame(
        key: widget.discipline,
        createdBy: widget.createdBy,
        olympiade: widget.olympiade,
        uids: _selectedUids,
        names: _selectedNames,
        settings: _settings,
        tracks: _trackIndices.map((i) => olympiadeMarioKartTracks[i].track).toList(),
      );
      if (gameId == null) throw Exception('Unbekannte Disziplin');

      await _service.setResult(
        olympiade: widget.olympiade,
        discipline: widget.discipline,
        result: _withNewGame(gameId),
      );

      if (!mounted) return;
      Navigator.pop(context, gameId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      _showError('Fehler beim Starten: $e');
    }
  }

  Future<void> _saveInstantResult(int winnerWg) async {
    final error = _validate();
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _isBusy = true);
    try {
      final gameId = await saveOlympiadeBierpongResult(
        olympiade: widget.olympiade,
        createdBy: widget.createdBy,
        uids: _selectedUids,
        names: _selectedNames,
        winnerWg: winnerWg,
      );
      await _service.setResult(
        olympiade: widget.olympiade,
        discipline: widget.discipline,
        result: _withNewGame(gameId, bierpongWinner: winnerWg),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      _showError('Fehler beim Speichern: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_info.icon, color: _info.color, size: 26),
                const SizedBox(width: 10),
                Text(
                  _info.name,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _info.color),
                ),
              ],
            ),
            if (_info.multiGame) ...[
              const SizedBox(height: 4),
              Text(
                'Spiel ${_current.gameIds.length + 1}'
                '${_current.gameIds.isEmpty ? '' : ' • bisher ${_info.tallyLabel} ${_current.tally.join(' : ')}'}',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.olympiade.edition.rulesFor(widget.discipline) case final rules?) ...[
              const SizedBox(height: 12),
              OlympiadeRuleCard(section: rules, showTitle: false),
            ],
            const SizedBox(height: 20),

            if (_hasSchedule) ...[
              _buildSchedule(),
              const SizedBox(height: 16),
            ],

            // Teilnehmer pro WG
            Text(
              _isDuel ? 'Wer tritt an?' : 'Wer spielt mit?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...List.generate(2, (i) => _buildParticipantPicker(i)),

            // Modus-Einstellungen
            if (widget.discipline == 'mariokart') ...[
              const SizedBox(height: 12),
              _buildTrackSelection(),
            ],
            ..._info.settings.map(_buildSettingSelector),
            const SizedBox(height: 20),

            // Starten bzw. bei Bierpong direkt den Gewinner wählen
            if (_info.instantResult) ...[
              const Text(
                'Wer hat gewonnen?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(2, (i) {
                  final color = olympiadeWgColors[i];
                  final names = _selectedNames[i];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color.withValues(alpha: 0.18),
                          foregroundColor: color,
                          side: BorderSide(color: color, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        ),
                        onPressed: _isBusy ? null : () => _saveInstantResult(i),
                        child: Column(
                          children: [
                            const Icon(Icons.emoji_events),
                            Text(
                              names.isNotEmpty ? names.first : widget.olympiade.wgs[i].name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.olympiade.wgs[i].name,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ] else
              ElevatedButton.icon(
                onPressed: _isBusy ? null : _start,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _info.color.withValues(alpha: 0.85),
                  foregroundColor: Colors.black,
                ),
                icon: _isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text(
                  'Disziplin starten',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantPicker(int wgIndex) {
    final wg = widget.olympiade.wgs[wgIndex];
    final color = olympiadeWgColors[wgIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(wg.name, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: List.generate(wg.playerUids.length, (p) {
              final uid = wg.playerUids[p];
              final isSelected = _selected[wgIndex].contains(uid);
              return FilterChip(
                label: Text(wg.playerNames[p]),
                selected: isSelected,
                showCheckmark: !_isDuel,
                selectedColor: color.withValues(alpha: 0.3),
                side: BorderSide(color: isSelected ? color : Colors.grey.shade700),
                onSelected: (selected) {
                  setState(() {
                    if (_isDuel) {
                      _selected[wgIndex] = {uid};
                    } else if (selected) {
                      _selected[wgIndex].add(uid);
                    } else {
                      _selected[wgIndex].remove(uid);
                    }
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- Spielplan jeder gegen jeden ---

  Widget _buildSchedule() {
    final open = _openPairings;
    final total = olympiadeRoundRobinTotal(widget.olympiade, widget.discipline) ?? 0;
    if (open == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
    }

    // Gleiche Paarungen zusammenfassen (Hin- und Rückrunde)
    final counts = <OlympiadePairing, int>{};
    for (final p in open) {
      counts[p] = (counts[p] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spielplan: ${total - open.length} von $total Matches gespielt',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (open.isEmpty)
          const Text(
            'Alle Matches sind gespielt. Ihr könnt die Disziplin in der Übersicht beenden '
            '(oder trotzdem noch ein Spiel eintragen).',
            style: TextStyle(color: Colors.greenAccent, fontSize: 13),
          )
        else ...[
          const Text(
            'Noch offen – antippen, um das Duell auszuwählen:',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: counts.entries.map((entry) {
              final p = entry.key;
              final isSelected = _selected[0].contains(p.a) && _selected[1].contains(p.b);
              return ChoiceChip(
                label: Text(
                  '${_playerName(0, p.a)} vs. ${_playerName(1, p.b)}'
                  '${entry.value > 1 ? ' (${entry.value}×)' : ''}',
                ),
                selected: isSelected,
                selectedColor: _info.color.withValues(alpha: 0.3),
                onSelected: (_) => setState(() => _selectPairing(p)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // --- Mario Kart: einzelne Strecken auswählen ---

  Widget _buildTrackSelection() {
    final tracks = olympiadeMarioKartTracks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Strecken (${_trackIndices.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                final shuffled = List.generate(tracks.length, (i) => i)..shuffle();
                setState(() {
                  _trackIndices
                    ..clear()
                    ..addAll(shuffled.take(4));
                });
              },
              icon: const Icon(Icons.casino_outlined, size: 18),
              label: const Text('4 zufällige'),
            ),
            TextButton.icon(
              onPressed: () {
                // Alle Strecken der 12 Hauptspiel-Cups in Cup-Reihenfolge
                setState(() {
                  _trackIndices
                    ..clear()
                    ..addAll([
                      for (int i = 0; i < tracks.length; i++)
                        if (MarioKartData.allCups.any(
                          (c) => c.category == 'Hauptspiel' && c.name == tracks[i].cup,
                        ))
                          i,
                    ]);
                });
              },
              icon: const Icon(Icons.select_all, size: 18),
              label: const Text('Alle 48'),
            ),
          ],
        ),
        if (_trackIndices.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6.0),
            child: Text(
              'Noch keine Strecken gewählt. Sie werden in der gewählten Reihenfolge gefahren.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: List.generate(_trackIndices.length, (n) {
              final track = tracks[_trackIndices[n]];
              return InputChip(
                avatar: CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: Text('${n + 1}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                ),
                label: Text(track.track),
                onDeleted: () => setState(() => _trackIndices.removeAt(n)),
              );
            }),
          ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _showTrackPicker,
          icon: const Icon(Icons.add_road, color: Colors.redAccent),
          label: const Text('Strecken auswählen'),
        ),
      ],
    );
  }

  void _showTrackPicker() {
    final tracks = olympiadeMarioKartTracks;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                void toggle(int index) {
                  setState(() {
                    if (_trackIndices.contains(index)) {
                      _trackIndices.remove(index);
                    } else {
                      _trackIndices.add(index);
                    }
                  });
                  setSheetState(() {});
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Strecken auswählen (${_trackIndices.length})',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Fertig'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: MarioKartData.allCups.map((cup) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cup.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: cup.tracks.map((trackName) {
                                    final index = tracks.indexWhere(
                                      (t) => t.cup == cup.name && t.track == trackName,
                                    );
                                    final position = _trackIndices.indexOf(index);
                                    return FilterChip(
                                      label: Text(
                                        position >= 0 ? '${position + 1}. $trackName' : trackName,
                                      ),
                                      selected: position >= 0,
                                      showCheckmark: false,
                                      selectedColor: Colors.redAccent.withValues(alpha: 0.3),
                                      onSelected: (_) => toggle(index),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSettingSelector(OlympiadeSetting setting) {
    final value = _settings[setting.key] ?? setting.defaultValue;
    void update(int v) => setState(() => _settings[setting.key] = v);

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(setting.label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: setting.presets.map((p) {
                    return ChoiceChip(
                      label: Text('$p'),
                      selected: value == p,
                      onSelected: (_) => update(p),
                    );
                  }).toList(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: value > setting.min ? () => update(value - 1) : null,
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
                onPressed: value < setting.max ? () => update(value + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
