import 'package:flutter/material.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLogin = true; // Switch zwischen Login und Registrierung
  bool _isLoading = false;
  String? _errorMessage;

  void _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? error;
    if (_isLogin) {
      error = await _authService.loginWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } else {
      if (_usernameController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Bitte gib einen Benutzernamen ein.';
          _isLoading = false;
        });
        return;
      }
      error = await _authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        username: _usernameController.text.trim(),
      );
    }

    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Anmelden' : 'Account erstellen'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.style, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              _isLogin ? 'Willkommen zurück!' : 'Spieleblock Cloud erstellen',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 30),

            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],

            if (!_isLogin) ...[
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Benutzername (z.B. Max)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-Mail Adresse',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Passwort',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text(
                      _isLogin ? 'Einloggen' : 'Registrieren',
                      style: const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
            ),

            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                  _errorMessage = null;
                });
              },
              child: Text(
                _isLogin
                    ? 'Noch keinen Account? Hier registrieren'
                    : 'Bereits registriert? Hier einloggen',
              ),
            ),
          ],
        ),
      ),
    );
  }
}