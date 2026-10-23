import 'package:flutter/material.dart';
import 'mariokart_models.dart';
import 'mariokart_service.dart';
import 'mariokart_data.dart';
import 'mariokart_group_stats_screen.dart';

class MarioKartScoreScreen extends StatefulWidget {
  final MarioKartGame game;
  final MarioKartService? service; // Optional, z.B. für Spiele einer WG Olympiade

  const MarioKartScoreScreen({super.key, required this.game, this.service});

  @override
  State<MarioKartScoreScreen> createState() => _MarioKartScoreScreenState();
}

class _MarioKartScoreScreenState extends State<MarioKartScoreScreen> {
  late final MarioKartService _service = widget.service ?? MarioKartService();

  void _showRaceDialog(MarioKartGame currentGame, int cupIndex, int trackIndex) {
    if (currentGame.status == 'finished') return;

    if (cupIndex >= currentGame.cups.length) return;
    final cupInfo = currentGame.cups[cupIndex];

    final trackName = trackIndex < cupInfo.tracks.length
        ? cupInfo.tracks[trackIndex]
        : 'Strecke ${trackIndex + 1}';

    // Prüfen, ob für diese Strecke schon ein Ergebnis vorliegt
    final existingRace = currentGame.races.cast<MarioKartRace?>().firstWhere(
          (r) => r?.cupIndex == cupIndex && r?.trackIndex == trackIndex,
          orElse: () => null,
        );

    // Platzierungen initialisieren
    final Map<String, int?> selectedPlacements = {};
    for (int i = 0; i < currentGame.playerUids.length; i++) {
      final uid = currentGame.playerUids[i];
      if (existingRace != null && existingRace.placements.containsKey(uid)) {
        selectedPlacements[uid] = existingRace.placements[uid];
      } else {
        selectedPlacements[uid] = (i + 1 <= 12) ? (i + 1) : 12;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final usedPlacements = selectedPlacements.values.whereType<int>().toSet();
            final hasDuplicates =
                selectedPlacements.values.whereType<int>().length != usedPlacements.length;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                top: 20,
                left: 16,
                right: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cup ${cupIndex + 1}: ${cupInfo.cupName}',
                      style: TextStyle(fontSize: 14, color: Colors.redAccent.shade100),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rennen ${trackIndex + 1} von ${currentGame.trackCountForCup(cupIndex)}: $trackName',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Wähle für jeden Fahrer die erreichte Platzierung:',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),

                    if (hasDuplicates)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade900.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.amberAccent, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Achtung: Mehrere Fahrer haben denselben Platz!',
                                style: TextStyle(fontSize: 13, color: Colors.amberAccent),
                              ),
                            ),
                          ],
                        ),
                      ),

                    ...currentGame.playerUids.map((uid) {
                      final name = currentGame.getPlayerName(uid);
                      final placement = selectedPlacements[uid] ?? 1;
                      final points = MarioKartData.getPointsForPlacement(placement);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: _getPlacementColor(placement),
                                child: Text(
                                  '$placement',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              Text(
                                '+$points Pkt.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 12),
                              DropdownButton<int>(
                                value: placement,
                                items: List.generate(12, (i) {
                                  final p = i + 1;
                                  return DropdownMenuItem<int>(
                                    value: p,
                                    child: Text('$p. Platz'),
                                  );
                                }),
                                onChanged: (newP) {
                                  if (newP != null) {
                                    setModalState(() {
                                      selectedPlacements[uid] = newP;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final finalPlacements = <String, int>{};
                        final finalPoints = <String, int>{};

                        for (var uid in currentGame.playerUids) {
                          final p = selectedPlacements[uid] ?? 1;
                          finalPlacements[uid] = p;
                          finalPoints[uid] = MarioKartData.getPointsForPlacement(p);
                        }

                        final updatedRace = MarioKartRace(
                          cupIndex: cupIndex,
                          trackIndex: trackIndex,
                          trackName: trackName,
                          placements: finalPlacements,
                          points: finalPoints,
                          timestamp: DateTime.now(),
                        );

                        // Rennen in die Liste einfügen oder aktualisieren
                        final updatedRaces = List<MarioKartRace>.from(currentGame.races);
                        final existingIdx = updatedRaces.indexWhere(
                          (r) => r.cupIndex == cupIndex && r.trackIndex == trackIndex,
                        );

                        if (existingIdx >= 0) {
                          updatedRaces[existingIdx] = updatedRace;
                        } else {
                          updatedRaces.add(updatedRace);
                          updatedRaces.sort((a, b) {
                            if (a.cupIndex != b.cupIndex) {
                              return a.cupIndex.compareTo(b.cupIndex);
                            }
                            return a.trackIndex.compareTo(b.trackIndex);
                          });
                        }

                        // Gesamtpunkte neu berechnen
                        final newTotals = <String, int>{};
                        for (var uid in currentGame.playerUids) {
                          newTotals[uid] = 0;
                        }
                        for (var race in updatedRaces) {
                          race.points.forEach((uid, pts) {
                            newTotals[uid] = (newTotals[uid] ?? 0) + pts;
                          });
                        }

                        if (currentGame.id != null) {
                          await _service.updateRacesAndTotals(
                            gameId: currentGame.id!,
                            races: updatedRaces,
                            totalScores: newTotals,
                          );
                        }

                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext);
                      },
                      child: Text(
                        existingRace != null ? 'Ergebnis aktualisieren' : 'Ergebnis speichern',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCupModal(MarioKartGame currentGame) {
    if (currentGame.status == 'finished') return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            final baseCups =
                MarioKartData.allCups.where((c) => c.category == 'Hauptspiel').toList();
            final boosterCups = MarioKartData.allCups
                .where((c) => c.category == 'Booster-Streckenpass')
                .toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nächsten Cup wählen (Cup ${currentGame.cups.length + 1})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      const Text(
                        'Hauptspiel Cups (12)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...baseCups.map((cup) => _buildAddCupTile(currentGame, cup)),
                      const SizedBox(height: 16),
                      const Text(
                        'Booster-Streckenpass Cups (12)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...boosterCups.map((cup) => _buildAddCupTile(currentGame, cup)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddTrackModal(MarioKartGame currentGame) {
    if (currentGame.status == 'finished') return;

    // Bereits gefahrene Strecken markieren
    final playedTracks = {
      for (final cup in currentGame.cups) ...cup.tracks,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nächste Strecke wählen',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0),
                    children: MarioKartData.allCups.map((cup) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cup.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cup.category == 'Hauptspiel'
                                    ? Colors.redAccent
                                    : Colors.amberAccent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: cup.tracks.map((track) {
                                final played = playedTracks.contains(track);
                                return ActionChip(
                                  avatar: played
                                      ? const Icon(Icons.check, size: 16, color: Colors.grey)
                                      : null,
                                  label: Text(
                                    track,
                                    style: TextStyle(color: played ? Colors.grey : Colors.white),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(sheetContext);
                                    if (currentGame.id != null) {
                                      await _service.addSingleTrack(
                                        gameId: currentGame.id!,
                                        track: track,
                                        currentCups: currentGame.cups,
                                      );
                                    }
                                  },
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
  }

  Widget _buildAddCupTile(MarioKartGame currentGame, MarioKartCup cup) {
    final bool alreadyPlayed = currentGame.cups.any((c) => c.cupId == cup.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: alreadyPlayed ? Colors.grey.shade800 : Colors.redAccent,
          child: const Icon(Icons.emoji_events, color: Colors.white, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                cup.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (alreadyPlayed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Schon gespielt', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
        subtitle: Text(
          cup.tracks.join(' • '),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.add_circle_outline, color: Colors.redAccent),
        onTap: () async {
          Navigator.pop(context);
          if (currentGame.id != null) {
            await _service.addNextCup(
              gameId: currentGame.id!,
              nextCup: cup,
              currentCups: currentGame.cups,
            );
          }
        },
      ),
    );
  }

  void _showPodiumCelebration(MarioKartGame game) {
    final scores = game.calculatedTotalScores;
    final sortedUids = List<String>.from(game.playerUids);
    sortedUids.sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🏆 Match-Siegerehrung!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gesamtergebnis nach ${game.cups.length} ${game.cups.length == 1 ? "Cup" : "Cups"} (${game.races.length} Strecken):',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (sortedUids.isNotEmpty)
              ListTile(
                leading: const Text('🥇', style: TextStyle(fontSize: 28)),
                title: Text(
                  game.getPlayerName(sortedUids[0]),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                trailing: Text(
                  '${scores[sortedUids[0]] ?? 0} Pkt.',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.amberAccent),
                ),
              ),
            if (sortedUids.length > 1)
              ListTile(
                leading: const Text('🥈', style: TextStyle(fontSize: 24)),
                title: Text(game.getPlayerName(sortedUids[1])),
                trailing: Text(
                  '${scores[sortedUids[1]] ?? 0} Pkt.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            if (sortedUids.length > 2)
              ListTile(
                leading: const Text('🥉', style: TextStyle(fontSize: 22)),
                title: Text(game.getPlayerName(sortedUids[2])),
                trailing: Text('${scores[sortedUids[2]] ?? 0} Pkt.'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Weiter ansehen'),
          ),
          if (game.status != 'finished')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(context);
                _confirmFinishGame(game);
              },
              child: const Text('Match offiziell beenden', style: TextStyle(color: Colors.black)),
            ),
        ],
      ),
    );
  }

  void _confirmFinishGame(MarioKartGame currentGame) async {
    // Vorherige beendete Spiele laden, um die aktuellen Multiplikatoren zu ermitteln
    List<MarioKartGame> groupGames = [];
    try {
      groupGames = await _service.getGamesForGroupStream(currentGame.groupId).first;
    } catch (_) {}

    final previousFinishedGames = groupGames
        .where((g) => g.id != currentGame.id && g.status == 'finished')
        .toList();

    final groupStats = MarioKartGroupStats(
      games: previousFinishedGames,
      playerUids: currentGame.playerUids,
      playerNames: currentGame.playerNames,
      useMultipliers: true,
    );

    final multipliers = groupStats.calculateMultipliersForMatch(currentGame.playerUids);
    final rawScores = currentGame.calculatedTotalScores;

    bool saveWithMultipliers = true;

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Mario Kart Match beenden?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Möchtest du dieses Match nach ${currentGame.cups.length} ${currentGame.cups.length == 1 ? "Cup" : "Cups"} offiziell abschließen?',
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 10),

                    // Schalter für Multiplikatoren
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: saveWithMultipliers,
                      activeThumbColor: Colors.amberAccent,
                      title: const Text(
                        'Zusätzlich mit Multiplikatoren speichern',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Speichert neben dem normalen Punktestand einen modifizierten Punktestand basierend auf der All-Time Rangliste.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          saveWithMultipliers = val;
                        });
                      },
                    ),

                    if (saveWithMultipliers) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.bolt, color: Colors.amberAccent, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Multiplikator-Vorschau:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...currentGame.playerUids.map((uid) {
                              final name = currentGame.getPlayerName(uid);
                              final rawPts = rawScores[uid] ?? 0;
                              final mult = multipliers[uid] ?? 1.0;
                              final modPts = rawPts * mult;
                              final modFormatted = modPts % 1 == 0
                                  ? modPts.toInt().toString()
                                  : modPts.toStringAsFixed(1);

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '$rawPts × $mult = ',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    Text(
                                      '$modFormatted Pkt.',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amberAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Abschließen', style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true && currentGame.id != null) {
      if (saveWithMultipliers) {
        final modifiedScores = <String, double>{};
        for (final uid in currentGame.playerUids) {
          final rawPts = rawScores[uid] ?? 0;
          final mult = multipliers[uid] ?? 1.0;
          modifiedScores[uid] = double.parse((rawPts * mult).toStringAsFixed(1));
        }

        await _service.finishGame(
          currentGame.id!,
          hasMultipliers: true,
          appliedMultipliers: multipliers,
          modifiedTotalScores: modifiedScores,
        );
      } else {
        await _service.finishGame(currentGame.id!, hasMultipliers: false);
      }

      if (mounted) {
        _showPodiumCelebration(currentGame);
      }
    }
  }

  void _confirmDiscardGame(MarioKartGame currentGame) async {
    final bool isFinished = currentGame.status == 'finished';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFinished ? 'Match löschen?' : 'Match verwerfen?'),
        content: Text(
          isFinished
              ? 'Möchtest du dieses beendete Match wirklich aus der Historie löschen?'
              : 'Möchtest du dieses laufende Match wirklich abbrechen und löschen? Alle bisherigen Strecken und Punkte werden unwiderruflich gelöscht.',
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
              isFinished
                  ? 'Das Match wurde gelöscht.'
                  : 'Das Match wurde abgebrochen und verworfen.',
            ),
          ),
        );
      }
    }
  }

  Color _getPlacementColor(int placement) {
    switch (placement) {
      case 1:
        return Colors.amber.shade600; // Gold
      case 2:
        return Colors.grey.shade400; // Silber
      case 3:
        return Colors.brown.shade400; // Bronze
      default:
        return Colors.blueGrey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.game.id == null) {
      return _buildScaffold(widget.game);
    }

    return StreamBuilder<MarioKartGame?>(
      stream: _service.getGameStream(widget.game.id!),
      initialData: widget.game,
      builder: (context, snapshot) {
        final currentGame = snapshot.data ?? widget.game;
        return _buildScaffold(currentGame);
      },
    );
  }

  Widget _buildScaffold(MarioKartGame currentGame) {
    final bool isFinished = currentGame.status == 'finished';
    final rankedUids = currentGame.rankedPlayerUids;
    final scores = currentGame.calculatedTotalScores;
    final bool activeCupFinished = currentGame.isActiveCupFinished;

    return Scaffold(
      appBar: AppBar(
        title: Text('${currentGame.groupName} 🏆'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Siegerehrung / Podium',
            onPressed: () => _showPodiumCelebration(currentGame),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'stats') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MarioKartGroupStatsScreen(
                      group: MarioKartGroup(
                        id: currentGame.groupId,
                        name: currentGame.groupName,
                        createdBy: currentGame.createdBy,
                        playerUids: currentGame.playerUids,
                        playerNames: currentGame.playerNames,
                        createdAt: currentGame.date,
                      ),
                    ),
                  ),
                );
              } else if (value == 'finish') {
                _confirmFinishGame(currentGame);
              } else if (value == 'discard') {
                _confirmDiscardGame(currentGame);
              }
            },
            itemBuilder: (context) => [
              // Spiele mit eigener Collection (WG Olympiade) gehören zu keiner Gruppe
              if (widget.service == null)
                const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Gruppen-Statistiken'),
                  ],
                ),
              ),
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isFinished)
              Container(
                width: double.infinity,
                color: Colors.grey.shade800.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events, size: 20, color: Colors.amberAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Match beendet (${currentGame.cups.length} Cups)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // --- GESAMTWERTUNG CARD ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                color: Colors.grey.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.leaderboard, color: Colors.amberAccent, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Gesamtwertung',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            '${currentGame.cups.length} ${currentGame.cups.length == 1 ? "Cup" : "Cups"} • ${currentGame.races.length} Strecken',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      ...List.generate(rankedUids.length, (rankIdx) {
                        final uid = rankedUids[rankIdx];
                        final name = currentGame.getPlayerName(uid);
                        final total = scores[uid] ?? 0;
                        final rank = rankIdx + 1;

                        String medal = '';
                        if (rank == 1) medal = '🥇';
                        if (rank == 2) medal = '🥈';
                        if (rank == 3) medal = '🥉';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  medal.isNotEmpty ? medal : '$rank.',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: rank == 1 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Text(
                                '$total Pkt.',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: rank == 1 ? Colors.amberAccent : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- AKTIONEN NACH ABGESCHLOSSENEM CUP ---
            if (!isFinished && activeCupFinished)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  color: Colors.grey.shade800.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          currentGame.cupId == MarioKartData.customCupId
                              ? '🏁 Alle Strecken gefahren!'
                              : '🏆 ${currentGame.activeCup.cupName} abgeschlossen!',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Weiter mit einer einzelnen Strecke, einem ganzen Cup – oder das Match jetzt beenden?',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.shade700,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () => _showAddTrackModal(currentGame),
                                icon: const Icon(Icons.add_road, color: Colors.white),
                                label: const Text(
                                  'Einzelne Strecke',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () => _showAddCupModal(currentGame),
                                icon: const Icon(Icons.emoji_events, size: 18),
                                label: const Text('Ganzer Cup'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.amberAccent,
                              side: const BorderSide(color: Colors.amberAccent),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _confirmFinishGame(currentGame),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Match beenden'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // --- LISTE ALLER GESPIELTEN CUPS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gespielte Cups:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (!isFinished && !activeCupFinished)
                        TextButton.icon(
                          onPressed: () => _showAddCupModal(currentGame),
                          icon: const Icon(Icons.add, size: 16, color: Colors.redAccent),
                          label: const Text('Weiterer Cup', style: TextStyle(color: Colors.redAccent)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...List.generate(currentGame.cups.length, (cupIndex) {
                    final cup = currentGame.cups[cupIndex];
                    final bool isCurrentActive = cupIndex == currentGame.activeCupIndex;
                    final bool isCupDone = currentGame.isCupFinished(cupIndex);
                    final cupRaces = currentGame.racesForCup(cupIndex);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      color: Colors.grey.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: isCurrentActive && !isCupDone
                            ? BorderSide(color: Colors.redAccent.shade400, width: 1.5)
                            : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cup Header
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isCupDone ? Colors.white : Colors.redAccent,
                                  child: Icon(
                                    isCupDone ? Icons.check : Icons.emoji_events,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cup ${cupIndex + 1}: ${cup.cupName}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '${cupRaces.length} von ${currentGame.trackCountForCup(cupIndex)} Strecken absolviert',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCupDone)
                                  const Chip(
                                    label: Text('Abgeschlossen', style: TextStyle(fontSize: 11)),
                                    backgroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  )
                                else if (isCurrentActive)
                                  const Chip(
                                    label: Text('Aktiv', style: TextStyle(fontSize: 11)),
                                    backgroundColor: Colors.redAccent,
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const Divider(height: 18),

                            // Die 4 Strecken dieses Cups
                            ...List.generate(cup.tracks.length, (trackIdx) {
                              final trackName = cup.tracks[trackIdx];
                              final race = currentGame.races.cast<MarioKartRace?>().firstWhere(
                                    (r) => r?.cupIndex == cupIndex && r?.trackIndex == trackIdx,
                                    orElse: () => null,
                                  );

                              final bool isTrackDone = race != null;
                              final bool isNextTrack = isCurrentActive &&
                                  trackIdx == cupRaces.length &&
                                  !isCupDone;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4.0),
                                padding: const EdgeInsets.all(10.0),
                                decoration: BoxDecoration(
                                  color: isTrackDone
                                      ? Colors.grey.shade800
                                      : (isNextTrack
                                          ? Colors.red.shade900.withValues(alpha: 0.25)
                                          : Colors.black26),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 11,
                                          backgroundColor: isTrackDone
                                              ? Colors.white
                                              : (isNextTrack ? Colors.redAccent : Colors.grey.shade700),
                                          child: Text(
                                            '${trackIdx + 1}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            trackName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isNextTrack ? FontWeight.bold : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (isTrackDone)
                                          const Icon(Icons.check_circle, size: 16, color: Colors.white)
                                        else if (isNextTrack)
                                          const Chip(
                                            label: Text('Nächstes Rennen', style: TextStyle(fontSize: 10)),
                                            backgroundColor: Colors.redAccent,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                      ],
                                    ),

                                    if (isTrackDone) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 2,
                                        children: currentGame.playerUids.map((uid) {
                                          final p = race.placements[uid] ?? 0;
                                          final pts = race.points[uid] ?? 0;
                                          final name = currentGame.getPlayerName(uid);
                                          return Text(
                                            '$name: $p. (+$pts)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: p == 1 ? Colors.amberAccent : Colors.grey.shade300,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],

                                    if (!isFinished) ...[
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () => _showRaceDialog(currentGame, cupIndex, trackIdx),
                                          icon: Icon(
                                            isTrackDone ? Icons.edit : Icons.sports_score,
                                            size: 15,
                                            color: isTrackDone ? Colors.grey : Colors.redAccent,
                                          ),
                                          label: Text(
                                            isTrackDone ? 'Ergebnis anpassen' : 'Platzierungen erfassen',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isTrackDone ? Colors.grey : Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _confirmDiscardGame(currentGame),
                icon: const Icon(Icons.delete_forever),
                label: Text(
                  isFinished
                      ? 'Match aus Historie löschen'
                      : 'Laufendes Match abbrechen & verwerfen',
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
