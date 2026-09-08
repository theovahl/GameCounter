import 'package:flutter/material.dart';
import 'doppelkopf_game_model.dart';
import 'doppelkopf_service.dart';

class ScoreScreen extends StatefulWidget {
  final DoppelkopfGame game; // Das Spiel mit den Daten aus Firestore

  const ScoreScreen({super.key, required this.game});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  final DoppelkopfService _doppelkopfService = DoppelkopfService();

  void _showAddRoundDialog(DoppelkopfGame currentGame) {
    // Diese Liste merkt sich für die 4 Spieler, wer im Gewinner-Team ist (true = Gewinner)
    List<bool> isWinner = [false, false, false, false];
    final scoreController = TextEditingController(text: '1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                  const Text(
                    'Runde auswerten',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text('Wer hat gewonnen? (Gewinner auswählen)'),
                  const SizedBox(height: 10),

                  // Generiert eine Liste der Spieler mit Checkboxen
                  Column(
                    children: List.generate(4, (index) {
                      return CheckboxListTile(
                        title: Text(currentGame.players[index]),
                        value: isWinner[index],
                        activeColor: Colors.white,
                        onChanged: (bool? value) {
                          setModalState(() {
                            isWinner[index] = value ?? false;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Textfeld für den Wert der Runde
                  TextField(
                    controller: scoreController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wert der Runde (Punkte)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.functions),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Speichern-Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      int baseScore = int.tryParse(scoreController.text) ?? 1;

                      // Punkte für die 4 Spieler berechnen
                      List<int> roundScores = [0, 0, 0, 0];
                      int numberOfWinners = isWinner.where((w) => w == true).length;
                      for (int i = 0; i < 4; i++) {
                        if (isWinner[i] && numberOfWinners == 1) {
                          roundScores[i] = baseScore * 3;
                        } else if (isWinner[i] && numberOfWinners >= 2) {
                          roundScores[i] = baseScore;
                        } else if (!isWinner[i] && numberOfWinners == 3) {
                          roundScores[i] = -(baseScore * 3);
                        } else {
                          roundScores[i] = -baseScore;
                        }
                      }

                      // Neue Gesamtpunkte berechnen
                      List<int> newTotals = List.generate(4, (i) {
                        int prev = (i < currentGame.totalScores.length)
                            ? currentGame.totalScores[i]
                            : 0;
                        return prev + roundScores[i];
                      });

                      final newRound = GameRound(
                        roundNumber: currentGame.rounds.length + 1,
                        scores: roundScores,
                        timestamp: DateTime.now(),
                      );

                      if (currentGame.id != null) {
                        await _doppelkopfService.addRound(
                          gameId: currentGame.id!,
                          round: newRound,
                          newTotalScores: newTotals,
                        );
                      }

                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Runde eintragen',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditRoundDialog(DoppelkopfGame currentGame, int roundIndex) {
    if (currentGame.status == 'finished') return;

    final round = currentGame.rounds[roundIndex];

    // Gewinner-Status ermitteln (alle Spieler mit positiven Punkten)
    List<bool> isWinner = List.generate(
      4,
      (i) => i < round.scores.length ? round.scores[i] > 0 : false,
    );

    // Initialen Rundenwert schätzen
    int initialBaseScore = 1;
    for (int s in round.scores) {
      if (s > 0) {
        int winnersCount = round.scores.where((x) => x > 0).length;
        if (winnersCount == 1) {
          initialBaseScore = (s / 3).round();
        } else {
          initialBaseScore = s;
        }
        break;
      }
    }
    if (initialBaseScore <= 0) initialBaseScore = 1;

    final scoreController = TextEditingController(text: '$initialBaseScore');
    final List<TextEditingController> manualControllers = List.generate(
      4,
      (i) => TextEditingController(
        text: i < round.scores.length ? '${round.scores[i]}' : '0',
      ),
    );

    bool isManualMode = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                      'Runde ${round.roundNumber} bearbeiten',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Standard-Wertung'),
                          icon: Icon(Icons.check_box),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Punkte pro Spieler'),
                          icon: Icon(Icons.edit_note),
                        ),
                      ],
                      selected: {isManualMode},
                      onSelectionChanged: (val) {
                        setModalState(() {
                          isManualMode = val.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    if (!isManualMode) ...[
                      const Text('Wer hat gewonnen? (Gewinner auswählen)'),
                      const SizedBox(height: 8),
                      Column(
                        children: List.generate(4, (index) {
                          return CheckboxListTile(
                            title: Text(currentGame.players[index]),
                            value: isWinner[index],
                            activeColor: Colors.white,
                            onChanged: (bool? value) {
                              setModalState(() {
                                isWinner[index] = value ?? false;
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: scoreController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Wert der Runde (Punkte)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.functions),
                        ),
                      ),
                    ] else ...[
                      const Text('Punkte direkt für jeden Spieler anpassen:'),
                      const SizedBox(height: 10),
                      ...List.generate(4, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: TextField(
                            controller: manualControllers[index],
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true),
                            decoration: InputDecoration(
                              labelText: currentGame.players[index],
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.person),
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 20),

                    // Speichern-Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        List<int> roundScores = [0, 0, 0, 0];

                        if (!isManualMode) {
                          int baseScore =
                              int.tryParse(scoreController.text) ?? 1;
                          int numberOfWinners =
                              isWinner.where((w) => w == true).length;
                          for (int i = 0; i < 4; i++) {
                            if (isWinner[i] && numberOfWinners == 1) {
                              roundScores[i] = baseScore * 3;
                            } else if (isWinner[i] && numberOfWinners >= 2) {
                              roundScores[i] = baseScore;
                            } else if (!isWinner[i] && numberOfWinners == 3) {
                              roundScores[i] = -(baseScore * 3);
                            } else {
                              roundScores[i] = -baseScore;
                            }
                          }
                        } else {
                          for (int i = 0; i < 4; i++) {
                            roundScores[i] =
                                int.tryParse(manualControllers[i].text.trim()) ??
                                    0;
                          }
                        }

                        // Aktualisierte Rundenliste bauen
                        final updatedRounds =
                            List<GameRound>.from(currentGame.rounds);
                        updatedRounds[roundIndex] = GameRound(
                          roundNumber: round.roundNumber,
                          scores: roundScores,
                          timestamp: round.timestamp ?? DateTime.now(),
                        );

                        // Gesamtpunkte neu berechnen
                        List<int> newTotals = [0, 0, 0, 0];
                        for (var r in updatedRounds) {
                          for (int i = 0; i < 4; i++) {
                            if (i < r.scores.length) {
                              newTotals[i] += r.scores[i];
                            }
                          }
                        }

                        if (currentGame.id != null) {
                          await _doppelkopfService.updateRounds(
                            gameId: currentGame.id!,
                            rounds: updatedRounds,
                            totalScores: newTotals,
                          );
                        }

                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Änderungen speichern',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                    const SizedBox(height: 10),

                    // Löschen-Button im Bearbeiten-Dialog
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _deleteRound(currentGame, roundIndex);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Runde löschen'),
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

  Future<void> _deleteRound(DoppelkopfGame currentGame, int roundIndex) async {
    if (currentGame.id == null) return;

    final round = currentGame.rounds[roundIndex];
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Runde ${round.roundNumber} löschen?'),
        content: const Text(
          'Möchtest du diese Runde wirklich löschen? Die nachfolgenden Runden werden neu nummeriert und die Gesamtpunktzahl wird automatisch neu berechnet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Löschen', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final updatedRounds = List<GameRound>.from(currentGame.rounds);
    updatedRounds.removeAt(roundIndex);

    // Runden neu nummerieren
    for (int i = 0; i < updatedRounds.length; i++) {
      updatedRounds[i] = GameRound(
        roundNumber: i + 1,
        scores: updatedRounds[i].scores,
        timestamp: updatedRounds[i].timestamp,
      );
    }

    // Gesamtpunkte neu berechnen
    List<int> newTotals = [0, 0, 0, 0];
    for (var r in updatedRounds) {
      for (int i = 0; i < 4; i++) {
        if (i < r.scores.length) {
          newTotals[i] += r.scores[i];
        }
      }
    }

    await _doppelkopfService.updateRounds(
      gameId: currentGame.id!,
      rounds: updatedRounds,
      totalScores: newTotals,
    );
  }

  void _confirmFinishGame(DoppelkopfGame currentGame) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spiel beenden?'),
        content: const Text(
            'Möchtest du dieses Spiel wirklich abschließen? Danach können keine weiteren Runden mehr eingetragen werden.'),
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
      await _doppelkopfService.finishGame(currentGame.id!);
    }
  }

  void _confirmDiscardGame(DoppelkopfGame currentGame) async {
    final bool isFinished = currentGame.status == 'finished';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFinished ? 'Spiel löschen?' : 'Spiel verwerfen?'),
        content: Text(
          isFinished
              ? 'Möchtest du dieses beendete Spiel wirklich aus der Historie löschen?'
              : 'Möchtest du dieses laufende Spiel wirklich abbrechen und löschen? Alle bisherigen Runden und Punkte werden unwiderruflich gelöscht.',
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
      await _doppelkopfService.deleteGame(currentGame.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFinished
                  ? 'Das Spiel wurde gelöscht.'
                  : 'Das Spiel wurde abgebrochen und verworfen.',
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

    return StreamBuilder<DoppelkopfGame?>(
      stream: _doppelkopfService.getGameStream(widget.game.id!),
      initialData: widget.game,
      builder: (context, snapshot) {
        final currentGame = snapshot.data ?? widget.game;
        return _buildScaffold(currentGame);
      },
    );
  }

  Widget _buildScaffold(DoppelkopfGame currentGame) {
    final bool isFinished = currentGame.status == 'finished';

    return Scaffold(
      appBar: AppBar(
        title: Text(currentGame.groupName.isNotEmpty
            ? currentGame.groupName
            : 'Doppelkopf Zähler'),
        centerTitle: true,
        actions: [
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
      body: Column(
        children: [
          if (isFinished)
            Container(
              width: double.infinity,
              color: Colors.orange.shade900.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag, size: 18, color: Colors.orangeAccent),
                  SizedBox(width: 8),
                  Text(
                    'Dieses Spiel ist abgeschlossen',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // 1. Kopfzeile mit Namen und aktuellen Gesamtpunkten
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (index) {
              final name = index < currentGame.players.length
                  ? currentGame.players[index]
                  : 'Spieler ${index + 1}';
              final score = index < currentGame.totalScores.length
                  ? currentGame.totalScores[index]
                  : 0;

              return Column(
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 26,
                      color: score > 0
                          ? Colors.white
                          : (score < 0 ? Colors.redAccent : Colors.grey),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(height: 30, thickness: 2),
          ),

          // 2. Dynamische Liste der bisherigen Runden
          Expanded(
            child: currentGame.rounds.isEmpty
                ? const Center(
                    child: Text(
                      'Noch keine Runden gespielt.\nKlicke auf das + um Punkte einzutragen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: currentGame.rounds.length,
                    itemBuilder: (context, index) {
                      final round = currentGame.rounds[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade800,
                          child: Text(
                            '${round.roundNumber}',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(4, (i) {
                            final score =
                                i < round.scores.length ? round.scores[i] : 0;
                            return Text(
                              score > 0 ? '+$score' : '$score',
                              style: TextStyle(
                                color: score > 0
                                    ? Colors.white
                                    : (score < 0 ? Colors.red : Colors.grey),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }),
                        ),
                        trailing: isFinished
                            ? null
                            : PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditRoundDialog(currentGame, index);
                                  } else if (value == 'delete') {
                                    _deleteRound(currentGame, index);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('Bearbeiten'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            size: 18, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text('Löschen',
                                            style: TextStyle(
                                                color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                        onTap: isFinished
                            ? null
                            : () => _showEditRoundDialog(currentGame, index),
                      );
                    },
                  ),
          ),
        ],
      ),

      // 3. Runden eintragen nur solange Spiel aktiv ist
      floatingActionButton: isFinished
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddRoundDialog(currentGame),
              backgroundColor: Colors.white,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }
}