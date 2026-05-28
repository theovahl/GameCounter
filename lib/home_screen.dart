import 'package:flutter/material.dart';
import 'doppelkopf/doppelkopf_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GameCounter'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Spiel auswählen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // 1. Kachel für Doppelkopf
            Card(
              elevation: 4,
              color: Colors.green.shade900, // Passendes Grün für Kartenspiele
              child: InkWell(
                onTap: () {
                  // Hier kommt die Magie: Wir springen zum DoppelkopfSetupScreen!
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SetupScreen()),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Icon(Icons.style, size: 40, color: Colors.white), // Kartensymbol
                      SizedBox(width: 16),
                      Text(
                        'Doppelkopf',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 2. Platzhalter für das nächste Spiel (z.B. Schafkopf oder Skat)
            Card(
              elevation: 2,
              color: Colors.grey.shade800,
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 40, color: Colors.grey),
                    SizedBox(width: 16),
                    Text(
                      'Skat (etc.)',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}