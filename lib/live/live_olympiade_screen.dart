import 'dart:async';
import 'package:flutter/material.dart';
import 'package:game_counter/darts/darts_models.dart';
import 'package:game_counter/olympiade/olympiade_models.dart';
import 'package:game_counter/olympiade/olympiade_service.dart';
import 'package:game_counter/olympiade/olympiade_disciplines.dart';
import 'package:game_counter/olympiade/olympiade_scoreboard.dart';
import 'package:game_counter/olympiade/olympiade_info_widgets.dart';

/// Zuschauer-Ansicht einer WG Olympiade. Liest die Olympiade und alle verknüpften
/// Spiele live aus Firestore und rechnet den Stand selbst aus – auch während ein
/// Spiel noch läuft und bevor die App synchronisiert hat.
class LiveOlympiadeScreen extends StatefulWidget {
  final String olympiadeId;

  const LiveOlympiadeScreen({super.key, required this.olympiadeId});

  @override
  State<LiveOlympiadeScreen> createState() => _LiveOlympiadeScreenState();
}

class _LiveOlympiadeScreenState extends State<LiveOlympiadeScreen> {
  final OlympiadeService _service = OlympiadeService();

  StreamSubscription<OlympiadeGame?>? _olympiadeSub;
  OlympiadeGame? _stored;
  bool _loaded = false;
  Object? _error;

  // Verknüpfte Spiele, Schlüssel "<disziplin>/<gameId>"
  final Map<String, StreamSubscription<Object?>> _gameSubs = {};
  final Map<String, Object?> _games = {};
  final Set<String> _unreadable = {};

  @override
  void initState() {
    super.initState();
    _olympiadeSub = _service.getOlympiadeStream(widget.olympiadeId).listen(
      (olympiade) {
        setState(() {
          _stored = olympiade;
          _loaded = true;
          _error = null;
        });
        if (olympiade != null) _updateGameSubscriptions(olympiade);
      },
      onError: (Object e) => setState(() {
        _error = e;
        _loaded = true;
      }),
    );
  }

  @override
  void dispose() {
    _olympiadeSub?.cancel();
    for (final sub in _gameSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  /// Hört auf alle aktuell verknüpften Spiele und beendet nicht mehr benötigte Streams
  void _updateGameSubscriptions(OlympiadeGame olympiade) {
    final needed = <String>{
      for (final d in olympiade.disciplines)
        for (final id in olympiade.resultFor(d).gameIds) '$d/$id',
    };

    for (final key in _gameSubs.keys.toList()) {
      if (!needed.contains(key)) {
        _gameSubs.remove(key)?.cancel();
        _games.remove(key);
        _unreadable.remove(key);
      }
    }

    for (final key in needed) {
      if (_gameSubs.containsKey(key)) continue;
      final slash = key.indexOf('/');
      final discipline = key.substring(0, slash);
      final gameId = key.substring(slash + 1);
      _gameSubs[key] = watchOlympiadeDisciplineGame(discipline, gameId, olympiade).listen(
        (game) => setState(() {
          _games[key] = game;
          _unreadable.remove(key);
        }),
        // Nicht lesbar (z.B. Spiele älterer Olympiaden in den normalen Modi):
        // dann den in der Olympiade gespeicherten Stand anzeigen
        onError: (Object _) => setState(() => _unreadable.add(key)),
      );
    }
  }

  List<Object?>? _gamesFor(String discipline, OlympiadeResult result) {
    final keys = result.gameIds.map((id) => '$discipline/$id').toList();
    // Solange nicht alle Spiele geladen (oder lesbar) sind, den gespeicherten Stand zeigen
    if (!keys.every(_games.containsKey) || keys.any(_unreadable.contains)) return null;
    return keys.map((k) => _games[k]).toList();
  }

  /// Olympiade mit live berechneten Ergebnissen aller Disziplinen
  OlympiadeGame _liveOlympiade(OlympiadeGame stored) {
    var live = stored;
    for (final d in stored.disciplines) {
      final result = stored.resultFor(d);
      final games = _gamesFor(d, result);
      if (games == null) continue;
      live = live.copyWithResult(
        d,
        olympiadeLiveResult(key: d, stored: result, games: games, olympiade: stored),
      );
    }
    return live;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const LiveMessageScreen(
        icon: Icons.lock_outline,
        title: 'Olympiade nicht verfügbar',
        message: 'Der Link ist ungültig oder die Olympiade ist nicht öffentlich sichtbar.',
      );
    }
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final stored = _stored;
    if (stored == null) {
      return const LiveMessageScreen(
        icon: Icons.search_off,
        title: 'Olympiade nicht gefunden',
        message: 'Diese Olympiade existiert nicht (mehr). Prüfe den Link.',
      );
    }

    final olympiade = _liveOlympiade(stored);
    final edition = olympiade.edition;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 68,
          title: _buildHeader(olympiade),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.amberAccent,
            labelColor: Colors.amberAccent,
            tabs: [
              Tab(icon: Icon(Icons.leaderboard), text: 'Live'),
              Tab(icon: Icon(Icons.menu_book), text: 'Regeln'),
              Tab(icon: Icon(Icons.schedule), text: 'Zeitplan'),
            ],
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final scale = wide ? 1.35 : 1.0;
              final infoScale = wide ? 1.15 : 1.0;
              return TabBarView(
                children: [
                  wide ? _buildWideLayout(olympiade, scale) : _buildNarrowLayout(olympiade),
                  _buildInfoTab(OlympiadeRulesList(edition: edition, scale: infoScale)),
                  _buildInfoTab(
                    OlympiadeScheduleList(edition: edition, olympiade: olympiade, scale: infoScale),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Regeln / Zeitplan: zentriert mit begrenzter Breite
  Widget _buildInfoTab(Widget child) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: child,
          ),
        ),
      ],
    );
  }

  // Handy: alles untereinander
  Widget _buildNarrowLayout(OlympiadeGame olympiade) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OlympiadeScoreboard(olympiade: olympiade),
        const SizedBox(height: 20),
        ..._buildDisciplineSections(olympiade, 1.0),
        const SizedBox(height: 24),
        _buildFooter(),
      ],
    );
  }

  // Laptop / Beamer: Medaillenspiegel links, Disziplinen rechts
  Widget _buildWideLayout(OlympiadeGame olympiade, double scale) {
    final running = olympiade.disciplines.where((d) => olympiade.resultFor(d).isRunning).toList();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: ListView(
                    children: [
                      OlympiadeScoreboard(olympiade: olympiade, scale: scale),
                      if (running.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader('Läuft gerade', Icons.play_circle_outline, scale),
                        ...running.map((d) => _buildDisciplineTile(olympiade, d, scale)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 4,
                  child: ListView(
                    children: [
                      ..._buildDisciplineSections(olympiade, scale, includeRunning: false),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(OlympiadeGame olympiade) {
    const scale = 1.0;
    final edition = olympiade.edition;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 30 * scale),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                edition.title,
                style: const TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${edition.number}. Ausgabe',
                style: const TextStyle(fontSize: 12 * scale, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (olympiade.status == 'active' && !olympiade.allDone)
          _LiveBadge(scale: scale)
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('BEENDET', style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  List<Widget> _buildDisciplineSections(
    OlympiadeGame olympiade,
    double scale, {
    bool includeRunning = true,
  }) {
    final running = olympiade.disciplines.where((d) => olympiade.resultFor(d).isRunning).toList();
    final done = olympiade.disciplines.where((d) => olympiade.resultFor(d).isDone).toList();
    final open = olympiade.disciplines.where((d) => olympiade.resultFor(d).isOpen).toList();

    return [
      if (includeRunning && running.isNotEmpty) ...[
        _buildSectionHeader('Läuft gerade', Icons.play_circle_outline, scale),
        ...running.map((d) => _buildDisciplineTile(olympiade, d, scale)),
        const SizedBox(height: 16),
      ],
      if (done.isNotEmpty) ...[
        _buildSectionHeader('Ergebnisse', Icons.check_circle_outline, scale),
        ...done.map((d) => _buildDisciplineTile(olympiade, d, scale)),
        const SizedBox(height: 16),
      ],
      if (open.isNotEmpty) ...[
        _buildSectionHeader(
          olympiade.status == 'finished' ? 'Nicht gespielt' : 'Noch offen',
          Icons.radio_button_unchecked,
          scale,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: open.map((d) {
            final info = olympiadeDiscipline(d);
            return Chip(
              avatar: Icon(info.icon, size: 18 * scale, color: info.color.withValues(alpha: 0.7)),
              label: Text(info.name, style: TextStyle(fontSize: 14 * scale)),
              side: BorderSide(color: Colors.grey.shade800),
            );
          }).toList(),
        ),
      ],
    ];
  }

  Widget _buildSectionHeader(String title, IconData icon, double scale) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18 * scale, color: Colors.grey),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDisciplineTile(OlympiadeGame olympiade, String discipline, double scale) {
    final info = olympiadeDiscipline(discipline);
    final result = olympiade.resultFor(discipline);
    final games = _gamesFor(discipline, result) ?? const [];
    final detail = olympiadeResultDetail(
      key: discipline,
      result: result,
      games: games,
      olympiade: olympiade,
    );
    final winner = result.winnerWg;

    // Bei laufenden Duellen zeigen, wer gerade gegeneinander antritt
    String? matchup;
    final lastGame = games.isNotEmpty ? games.last : null;
    if (result.isRunning && lastGame is DartsGame && lastGame.status == 'active') {
      matchup = '${lastGame.playerNames.join(' vs. ')} • Legs ${lastGame.legsWon.join(' : ')}';
    }

    Widget trailing;
    if (result.isDone && winner == olympiadeDraw) {
      trailing = _statusChip('Unentschieden', Colors.white70, Icons.handshake_outlined, scale);
    } else if (result.isDone) {
      trailing = _statusChip(olympiade.wgs[winner!].name, olympiadeWgColors[winner], Icons.emoji_events, scale);
    } else {
      trailing = _statusChip('läuft', Colors.redAccent, Icons.circle, scale, small: true);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: info.color, width: 4)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10 * scale),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20 * scale,
              backgroundColor: info.color.withValues(alpha: 0.18),
              child: Icon(info.icon, color: info.color, size: 22 * scale),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.name, style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
                  if (detail.isNotEmpty)
                    Text(detail, style: TextStyle(fontSize: 13 * scale, color: Colors.white70)),
                  if (matchup != null)
                    Text(matchup, style: TextStyle(fontSize: 12 * scale, color: Colors.amberAccent)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color, IconData icon, double scale, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: (small ? 10 : 16) * scale, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const Text(
      'Der Stand aktualisiert sich automatisch.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
}

// Pulsierendes "LIVE"-Abzeichen
class _LiveBadge extends StatefulWidget {
  final double scale;

  const _LiveBadge({required this.scale});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _controller,
            child: Icon(Icons.circle, size: 10 * widget.scale, color: Colors.redAccent),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 12 * widget.scale,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Einfache Hinweisseite (kein Link, nicht gefunden, keine Berechtigung)
class LiveMessageScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const LiveMessageScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
