import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_theme.dart';
import 'live/live_olympiade_screen.dart';

// Einstiegspunkt der Zuschauer-Website (ohne Login).
// Bauen:  flutter build web -t lib/main_live.dart
// Aufruf: https://game-counter-tv.web.app/?o=<olympiadeId>
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(LiveApp(olympiadeId: _olympiadeIdFromUrl()));
}

String? _olympiadeIdFromUrl() {
  final id = Uri.base.queryParameters['o'];
  if (id != null && id.isNotEmpty) return id;

  // Alternativ: .../#/live/<id>
  final segments = Uri.base.fragment.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.length >= 2 && segments[0] == 'live') return segments[1];
  return null;
}

class LiveApp extends StatelessWidget {
  final String? olympiadeId;

  const LiveApp({super.key, required this.olympiadeId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WG Olympiade – Live',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: olympiadeId != null
          ? LiveOlympiadeScreen(olympiadeId: olympiadeId!)
          : const LiveMessageScreen(
              icon: Icons.link_off,
              title: 'Kein Live-Link',
              message: 'Öffne den Live-Link, den du aus der GameCounter-App bekommen hast.',
            ),
    );
  }
}
