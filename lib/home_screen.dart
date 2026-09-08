import 'package:flutter/material.dart';
import 'doppelkopf/doppelkopf_setup_screen.dart';
import 'mariokart/mariokart_setup_screen.dart';
import 'auth_service.dart';
import 'friends_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('GameCounter'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Freunde',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Abmelden',
            onPressed: () async {
              // Bestätigungs-Dialog vor dem Abmelden
              bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Abmelden'),
                  content: const Text('Möchtest du dich wirklich abmelden?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Abbrechen'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Abmelden', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await authService.signOut();
              }
            },
          ),
        ],
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
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.amberAccent, width: 4)),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SetupScreen()),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Icon(Icons.style, size: 40, color: Colors.amberAccent), // Kartensymbol mit leichtem Akzent
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
            ),
            
            const SizedBox(height: 16),
            
            // 2. Kachel für Mario Kart 8 Deluxe
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.redAccent, width: 4)),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MarioKartSetupScreen()),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Icon(Icons.sports_motorsports, size: 40, color: Colors.redAccent),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mario Kart',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              '8 Deluxe • Grand Prix Zähler',
                              style: TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}