import 'package:flutter/material.dart';
import 'package:game_counter/database_helper.dart';
import 'doppelkopf_game_model.dart';

class ScoreScreen extends StatefulWidget {
  final DoppelkopfGame game; // Das Spiel mit den echten Namen aus dem Setup

  const ScoreScreen({super.key, required this.game});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  void _showAddRoundDialog() {
  // Diese Liste merkt sich für die 4 Spieler, wer im Gewinner-Team ist (true = Gewinner)
  List<bool> isWinner = [false, false, false, false];
  // Ein Controller, um die eingegebene Punktzahl aus dem Textfeld zu lesen
  final scoreController = TextEditingController(text: '1');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Erlaubt es dem Dialog, mit der Tastatur hochzurutschen
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, // Schiebt Dialog über die Tastatur
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
                      title: Text(widget.game.players[index]),
                      value: isWinner[index],
                      activeColor: Colors.green,
                      onChanged: (bool? value) {
                        // Wichtig: setModalState aktualisiert das UI *im* Dialog
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
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    // 1. Eingegebene Punkte auslesen (Sicherheits-Check falls keine Zahl eingegeben wurde)
                    int baseScore = int.tryParse(scoreController.text) ?? 1;
                    
                    // 2. Punkte-Liste für die 4 Spieler berechnen
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

                    final newRound = GameRound(
                      gameId: widget.game.id!, // Die ID, die wir im Setup-Screen generiert haben!
                      roundNumber: widget.game.rounds.length + 1,
                      scores: roundScores,
                    );

                    // NEU: In der lokalen SQLite-Datenbank für immer speichern
                    await DatabaseHelper.instance.createRound(newRound);

                    // Das Haupt-UI aktualisieren
                    setState(() {
                      widget.game.rounds.add(newRound);
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('Runde eintragen', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      );
    },
  );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doppelkopf Zähler'),
        centerTitle: true,
        // Optional: Ein Zurück-Button, der automatisch von Flutter generiert wird,
        // bringt dich zurück zum Setup-Screen.
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          
          // 1. Die Kopfzeile mit Namen und Gesamtpunkten
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (index) {
              return Column(
                children: [
                  Text(
                    widget.game.players[index],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.game.totalScores[index]}',
                    style: const TextStyle(
                      fontSize: 26, 
                      color: Colors.greenAccent, 
                      fontWeight: FontWeight.bold
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
          
          // 2. Die dynamische Liste der bisherigen Runden
          Expanded(
            child: widget.game.rounds.isEmpty
                ? const Center(
                    child: Text(
                      'Noch keine Runden gespielt.\nKlicke auf das + um Punkte einzutragen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.game.rounds.length,
                    itemBuilder: (context, index) {
                      final round = widget.game.rounds[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade800,
                          child: Text(
                            '${round.roundNumber}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(4, (i) {
                            final score = round.scores[i];
                            return Text(
                              score > 0 ? '+$score' : '$score',
                              style: TextStyle(
                                color: score > 0 
                                    ? Colors.green 
                                    : (score < 0 ? Colors.red : Colors.grey),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      
      // 3. Der Button für neue Runden
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRoundDialog, 
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}