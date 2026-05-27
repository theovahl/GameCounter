import 'package:flutter/material.dart';
import 'doppelkopf_game_model.dart';
import 'doppelkopf_score_screen.dart'; 

class DoppelkopfSetupScreen extends StatefulWidget {
  const DoppelkopfSetupScreen({super.key});

  @override
  State<DoppelkopfSetupScreen> createState() => _DoppelkopfSetupScreenState();
}

class _DoppelkopfSetupScreenState extends State<DoppelkopfSetupScreen> {
  // Controller, um den Text aus den Eingabefeldern auszulesen
  final List<TextEditingController> _controllers = 
      List.generate(4, (_) => TextEditingController());

  @override
  void dispose() {
    // Controller sauber löschen, wenn der Bildschirm verlassen wird
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startGame() {
    List<String> playerNames = [];
    
    // Namen auslesen. Wenn ein Feld leer ist, Standardnamen vergeben
    for (int i = 0; i < 4; i++) {
      String name = _controllers[i].text.trim();
      if (name.isEmpty) {
        playerNames.add('Spieler ${i + 1}');
      } else {
        playerNames.add(name);
      }
    }

    // Neues Spiel-Objekt mit den echten Namen erstellen
    final newGame = DoppelkopfGame(players: playerNames);

    // Zum ScoreScreen springen und das erstellte Spiel übergeben
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScoreScreen(game: newGame)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spieler Setup'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Wer spielt mit?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Die 4 Textfelder generieren
            Expanded(
              child: ListView.builder(
                itemCount: 4,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: _controllers[index],
                      decoration: InputDecoration(
                        labelText: 'Spieler ${index + 1}',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Start-Button ganz unten
            ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green.shade700,
              ),
              child: const Text(
                'Spiel starten',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}