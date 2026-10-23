import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import 'app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const DoppelkopfApp());
}

class DoppelkopfApp extends StatelessWidget {
  const DoppelkopfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spieleblock Zähler',
      theme: buildAppTheme(),
      // Der AuthWrapper entscheidet automatisch, welcher Screen gezeigt wird
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.userStream,
      builder: (context, snapshot) {
        // Während Firebase den Status lädt:
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Wenn ein User eingeloggt ist -> Hauptmenü
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // Wenn nicht eingeloggt -> Login Bildschirm
        return const LoginScreen();
      },
    );
  }
}