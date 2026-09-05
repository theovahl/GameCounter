import 'dart:math';
import 'package:flutter/material.dart';
import 'mariokart_models.dart';
import 'mariokart_data.dart';
import 'mariokart_service.dart';
import 'mariokart_score_screen.dart';

enum _StatsMode { standard, multipliers }
enum _StatsTab { leaderboard, progression, matches }
enum _ProgressionMode { races, matches }

class MarioKartGroupStatsScreen extends StatefulWidget {
  final MarioKartGroup group;
  final bool initialWithMultipliers;

  const MarioKartGroupStatsScreen({
    super.key,
    required this.group,
    this.initialWithMultipliers = false,
  });

  @override
  State<MarioKartGroupStatsScreen> createState() => _MarioKartGroupStatsScreenState();
}

class _MarioKartGroupStatsScreenState extends State<MarioKartGroupStatsScreen> {
  final MarioKartService _service = MarioKartService();
  late _StatsMode _statsMode;
  _StatsTab _selectedTab = _StatsTab.leaderboard;
  _ProgressionMode _progressionMode = _ProgressionMode.races;

  @override
  void initState() {
    super.initState();
    _statsMode =
        widget.initialWithMultipliers ? _StatsMode.multipliers : _StatsMode.standard;
  }

  // Farbpalette für bis zu 12 Spieler im Diagramm
  static const List<Color> _playerColors = [
    Color(0xFFE53935), // Rot (Mario)
    Color(0xFF1E88E5), // Blau
    Color(0xFF43A047), // Grün (Luigi)
    Color(0xFFFFB300), // Bernstein / Gelb
    Color(0xFF8E24AA), // Lila (Waluigi)
    Color(0xFF00ACC1), // Cyan
    Color(0xFFFB8C00), // Orange
    Color(0xFFD81B60), // Pink (Peach)
    Color(0xFF00897B), // Teal
    Color(0xFF5E35B1), // Deep Purple
    Color(0xFF7CB342), // Lime (Yoshi)
    Color(0xFF3949AB), // Indigo
  ];

  Color _getPlayerColor(int index) {
    return _playerColors[index % _playerColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isMulti = _statsMode == _StatsMode.multipliers;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.group.name} – Statistiken'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<MarioKartGame>>(
        stream: _service.getGamesForGroupStream(widget.group.id ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Fehler beim Laden der Statistiken:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final games = snapshot.data ?? [];
          final stats = MarioKartGroupStats(
            games: games,
            playerUids: widget.group.playerUids,
            playerNames: widget.group.playerNames,
            useMultipliers: isMulti,
          );

          return Column(
            children: [
              // Modus-Umschalter: Klassisch vs. Multiplikatoren
              _buildModeSelector(),

              if (isMulti)
                Container(
                  width: double.infinity,
                  color: Colors.amber.shade900.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: const Row(
                    children: [
                      Icon(Icons.bolt, size: 16, color: Colors.amberAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Handicap-Modus: 1. = 1.0, 2. = 1.1, 3. = 1.22, 4. = 1.36 auf Match-Punkte.',
                          style: TextStyle(fontSize: 11, color: Colors.amberAccent),
                        ),
                      ),
                    ],
                  ),
                ),

              // Gruppen-Übersichts-Header
              _buildHeader(stats),

              // Segmentierter Tab-Selector
              _buildTabSelector(),

              // Tab-Inhalt
              Expanded(
                child: games.isEmpty
                    ? _buildEmptyState()
                    : _buildTabContent(stats, games),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SegmentedButton<_StatsMode>(
        segments: const [
          ButtonSegment(
            value: _StatsMode.standard,
            icon: Icon(Icons.leaderboard, size: 16),
            label: Text('Klassisch'),
          ),
          ButtonSegment(
            value: _StatsMode.multipliers,
            icon: Icon(Icons.bolt, size: 16, color: Colors.amberAccent),
            label: Text('⚡ Multiplikatoren'),
          ),
        ],
        selected: {_statsMode},
        onSelectionChanged: (set) {
          setState(() {
            _statsMode = set.first;
          });
        },
      ),
    );
  }

  Widget _buildHeader(MarioKartGroupStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildHeaderStat(
            icon: Icons.sports_esports,
            label: 'Matches',
            value: '${stats.totalMatches}',
            color: Colors.blueAccent,
          ),
          _buildHeaderStat(
            icon: Icons.flag,
            label: 'Strecken',
            value: '${stats.totalRaces}',
            color: Colors.amberAccent,
          ),
          _buildHeaderStat(
            icon: Icons.people,
            label: 'Fahrer',
            value: '${widget.group.playerNames.length}',
            color: Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SegmentedButton<_StatsTab>(
        segments: const [
          ButtonSegment(
            value: _StatsTab.leaderboard,
            icon: Icon(Icons.emoji_events, size: 18),
            label: Text('Ewige Tabelle'),
          ),
          ButtonSegment(
            value: _StatsTab.progression,
            icon: Icon(Icons.show_chart, size: 18),
            label: Text('Verlauf'),
          ),
          ButtonSegment(
            value: _StatsTab.matches,
            icon: Icon(Icons.history, size: 18),
            label: Text('Matches'),
          ),
        ],
        selected: {_selectedTab},
        onSelectionChanged: (set) {
          setState(() {
            _selectedTab = set.first;
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text(
              'Noch keine Matches für diese Gruppe',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Starte einen Grand Prix mit dieser Gruppe. Sobald die ersten Rennen gefahren wurden, siehst du hier alle Rekorde, den Punkteverlauf und die ewige Tabelle!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(MarioKartGroupStats stats, List<MarioKartGame> games) {
    switch (_selectedTab) {
      case _StatsTab.leaderboard:
        return _buildLeaderboardTab(stats);
      case _StatsTab.progression:
        return _buildProgressionTab(stats);
      case _StatsTab.matches:
        return _buildMatchesTab(games);
    }
  }

  // --- TAB 1: EWIGE TABELLE ---
  Widget _buildLeaderboardTab(MarioKartGroupStats stats) {
    final leaderboard = stats.leaderboard;
    if (leaderboard.isEmpty) {
      return const Center(child: Text('Keine Daten vorhanden.'));
    }

    final topPlayer = leaderboard.first;
    final isMulti = _statsMode == _StatsMode.multipliers;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Top Performer Highlight Card
        if (topPlayer.totalPoints > 0)
          Card(
            color: Colors.amber.shade900.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.amber.shade700, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber.shade700,
                    ),
                    child: const Icon(Icons.emoji_events, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMulti
                              ? 'Multiplikator-Spitzenreiter 👑'
                              : 'Allzeit-Spitzenreiter 👑',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          topPlayer.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${topPlayer.formattedTotalPoints} Punkte • ${topPlayer.wins} Siege (${topPlayer.winRatePercentage.toStringAsFixed(1)}% Siegquote)',
                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isMulti
                  ? 'Rangliste (Multiplikator-Punkte):'
                  : 'Rangliste nach Gesamtpunkten:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Fahrer-Liste
        ...leaderboard.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final player = entry.value;
          final color = _getPlayerColor(entry.key);
          final nextMultiplier = MarioKartData.getMultiplierForRank(rank);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 5.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildRankBadge(rank),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  player.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${player.racesCount} Strecken in ${player.matchesPlayed} Matches',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            player.formattedTotalPoints,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          ),
                          const Text(
                            'Punkte',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Divider(height: 16),

                  // Medaillenspiegel, Quoten & Handicap-Faktor
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMedalBadge('🥇', '${player.wins}'),
                      _buildMedalBadge('🥈', '${player.secondPlaces}'),
                      _buildMedalBadge('🥉', '${player.thirdPlaces}'),
                      _buildStatChip(
                        'Ø ${player.avgPointsPerRace.toStringAsFixed(1)} Pkt.',
                        Colors.blueGrey,
                      ),
                      if (isMulti)
                        _buildStatChip(
                          'Handicap: ×$nextMultiplier',
                          Colors.amber.shade900,
                        )
                      else
                        _buildStatChip(
                          '${player.winRatePercentage.toStringAsFixed(0)}% Siege',
                          Colors.green.shade800,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFFFFD700),
        child: Text('🥇', style: TextStyle(fontSize: 18)),
      );
    } else if (rank == 2) {
      return const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFFC0C0C0),
        child: Text('🥈', style: TextStyle(fontSize: 18)),
      );
    } else if (rank == 3) {
      return const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFFCD7F32),
        child: Text('🥉', style: TextStyle(fontSize: 18)),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey.shade800,
      child: Text(
        '#$rank',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMedalBadge(String emoji, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          count,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatChip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bg.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  // --- TAB 2: PUNKTEVERLAUF (CHART) ---
  Widget _buildProgressionTab(MarioKartGroupStats stats) {
    final points = _progressionMode == _ProgressionMode.races
        ? stats.raceProgression
        : stats.matchProgression;

    if (points.length <= 1) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.show_chart, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Noch keine Daten für einen Verlauf vorhanden.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sobald die ersten Strecken gefahren wurden, siehst du hier den Punkteverlauf jedes Fahrers als Kurvendiagramm!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Spieler-Liste für Diagramm
    final leaderboard = stats.leaderboard;
    final allUids = leaderboard.map((p) => p.uid).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Schalter: Rennen vs. Matches
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _statsMode == _StatsMode.multipliers
                    ? 'Verlauf (Multiplikatoren):'
                    : 'Punkteverlauf:',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SegmentedButton<_ProgressionMode>(
                segments: const [
                  ButtonSegment(
                    value: _ProgressionMode.races,
                    label: Text('Nach Rennen'),
                  ),
                  ButtonSegment(
                    value: _ProgressionMode.matches,
                    label: Text('Nach Matches'),
                  ),
                ],
                selected: {_progressionMode},
                onSelectionChanged: (set) {
                  setState(() {
                    _progressionMode = set.first;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Diagramm-Karte
          Card(
            color: Colors.grey.shade900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenW = constraints.maxWidth;
                      final minRequiredWidth = max(screenW, points.length * 52.0);

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: minRequiredWidth,
                          height: 240,
                          child: CustomPaint(
                            size: Size(minRequiredWidth, 240),
                            painter: _ProgressionChartPainter(
                              points: points,
                              playerUids: allUids,
                              playerColors: List.generate(
                                allUids.length,
                                (i) => _getPlayerColor(i),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '← Horizontal wischen bei vielen Datenpunkten →',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Legende aller Fahrer
          const Text(
            'Fahrer & aktueller Punktestand:',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: leaderboard.asMap().entries.map((entry) {
              final color = _getPlayerColor(entry.key);
              final player = entry.value;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      player.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${player.formattedTotalPoints} Pkt.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: MATCH-HISTORIE ---
  Widget _buildMatchesTab(List<MarioKartGame> games) {
    final reversedGames = games.reversed.toList();
    final isMulti = _statsMode == _StatsMode.multipliers;

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: reversedGames.length,
      itemBuilder: (context, index) {
        final game = reversedGames[index];
        final isFinished = game.status == 'finished';

        final scores = (isMulti && game.hasMultipliers && game.modifiedTotalScores.isNotEmpty)
            ? game.modifiedTotalScores
            : game.calculatedTotalScores.map((k, v) => MapEntry(k, v.toDouble()));

        final rankedUids = (isMulti && game.hasMultipliers)
            ? game.rankedModifiedPlayerUids
            : game.rankedPlayerUids;

        final winnerUid = rankedUids.isNotEmpty ? rankedUids.first : null;
        final winnerName = winnerUid != null ? game.getPlayerName(winnerUid) : null;
        final winnerScore = winnerUid != null ? (scores[winnerUid] ?? 0.0) : 0.0;
        final winnerScoreFormatted = winnerScore % 1 == 0
            ? winnerScore.toInt().toString()
            : winnerScore.toStringAsFixed(1);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MarioKartScoreScreen(game: game),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _formatDate(game.date),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (game.hasMultipliers)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade900.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.7)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt, size: 12, color: Colors.amberAccent),
                                  SizedBox(width: 2),
                                  Text(
                                    'Multiplikator',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amberAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isFinished
                                  ? Colors.green.shade900.withValues(alpha: 0.4)
                                  : Colors.amber.shade900.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isFinished ? Colors.greenAccent : Colors.amberAccent,
                              ),
                            ),
                            child: Text(
                              isFinished ? 'Beendet' : 'Laufend',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isFinished ? Colors.greenAccent : Colors.amberAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cups: ${game.cups.map((c) => c.cupName).join(', ')}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  Text(
                    '${game.races.length} Strecken absolviert',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),

                  if (winnerName != null && isFinished && winnerScore > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            isMulti && game.hasMultipliers
                                ? 'Sieger: $winnerName ($winnerScoreFormatted Pkt. modifiziert)'
                                : 'Sieger: $winnerName ($winnerScoreFormatted Pkt.)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Mini-Punkteübersicht der Spieler
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: rankedUids.asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final uid = entry.value;
                      final name = game.getPlayerName(uid);
                      final pts = scores[uid] ?? 0.0;
                      final ptsFormatted = pts % 1 == 0
                          ? pts.toInt().toString()
                          : pts.toStringAsFixed(1);
                      final mult = game.appliedMultipliers[uid];

                      final text = (isMulti && game.hasMultipliers && mult != null)
                          ? '#$rank $name: $ptsFormatted Pkt. (×$mult)'
                          : '#$rank $name: $ptsFormatted Pkt.';

                      return Text(
                        text,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$day.$month.$year, $hour:$min Uhr';
  }
}

/// Benutzerdefinierter CustomPainter für das interaktive Mario Kart Punkteverlaufs-Diagramm
class _ProgressionChartPainter extends CustomPainter {
  final List<ProgressionPoint> points;
  final List<String> playerUids;
  final List<Color> playerColors;

  _ProgressionChartPainter({
    required this.points,
    required this.playerUids,
    required this.playerColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || playerUids.isEmpty) return;

    const double leftPadding = 42.0;
    const double rightPadding = 24.0;
    const double topPadding = 20.0;
    const double bottomPadding = 36.0;

    final double chartWidth = size.width - leftPadding - rightPadding;
    final double chartHeight = size.height - topPadding - bottomPadding;

    // Höchste Punktzahl im Verlauf ermitteln
    double maxScore = 15.0;
    for (final pt in points) {
      for (final score in pt.cumulativePoints.values) {
        if (score > maxScore) maxScore = score;
      }
    }

    // Gerundete Obergrenze für Y-Achse
    final int yUpper = ((maxScore + 10) / 10).ceil() * 10;

    // Y-Gitterlinien und Beschriftungen
    final Paint gridPaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 0.8;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    const int gridSteps = 4;
    for (int i = 0; i <= gridSteps; i++) {
      final double scoreVal = (yUpper / gridSteps) * i;
      final double y = topPadding + chartHeight - (scoreVal / yUpper) * chartHeight;

      // Linie
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Y-Label
      textPainter.text = TextSpan(
        text: '${scoreVal.toInt()}',
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      );
      textPainter.layout(minWidth: leftPadding - 6);
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    // X-Achsen-Labels
    final int count = points.length;
    final double stepX = count > 1 ? chartWidth / (count - 1) : chartWidth;

    for (int i = 0; i < count; i++) {
      final double x = leftPadding + (i * stepX);

      // Vertikale Hilfslinie
      canvas.drawLine(
        Offset(x, topPadding),
        Offset(x, topPadding + chartHeight),
        Paint()
          ..color = Colors.grey.shade800.withValues(alpha: 0.5)
          ..strokeWidth = 0.5,
      );

      // Nur jedes N-te Label zeichnen, falls zu voll
      final shouldShowLabel = count <= 12 || i == 0 || i == count - 1 || i % ((count / 8).ceil()) == 0;
      if (shouldShowLabel) {
        final labelText = points[i].label;
        final truncatedLabel = labelText.length > 7 ? '${labelText.substring(0, 6)}…' : labelText;

        final labelPainter = TextPainter(
          text: TextSpan(
            text: truncatedLabel,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        labelPainter.layout(minWidth: 40);
        labelPainter.paint(canvas, Offset(x - 20, topPadding + chartHeight + 8));
      }
    }

    // Graphen für jeden Spieler zeichnen
    for (int pIdx = 0; pIdx < playerUids.length; pIdx++) {
      final uid = playerUids[pIdx];
      final color = playerColors[pIdx % playerColors.length];

      final Paint linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final Paint dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final Paint dotBorderPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final Path path = Path();
      final List<Offset> dotOffsets = [];

      for (int i = 0; i < count; i++) {
        final double x = leftPadding + (i * stepX);
        final double score = points[i].cumulativePoints[uid] ?? 0.0;
        final double y = topPadding + chartHeight - (score / yUpper) * chartHeight;
        final offset = Offset(x, y);

        dotOffsets.add(offset);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Linie zeichnen
      canvas.drawPath(path, linePaint);

      // Datenpunkte zeichnen
      for (final offset in dotOffsets) {
        canvas.drawCircle(offset, 4.0, dotPaint);
        canvas.drawCircle(offset, 4.0, dotBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressionChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.playerUids != playerUids;
  }
}
