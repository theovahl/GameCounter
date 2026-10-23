import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// Die WG Olympiade bringt ihre Disziplinen selbst mit (lib/olympiade/ausgabe_*/).
// Diese Tests stellen sicher, dass sie unabhängig von den normalen Spielmodi bleibt.

const _normalModes = [
  'mariokart', 'doppelkopf',
];

Iterable<(String, String)> _imports(String dir) sync* {
  for (final file in Directory(dir).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    for (final line in file.readAsLinesSync()) {
      if (line.startsWith('import ')) yield (file.path, line);
    }
  }
}

void main() {
  test('the olympiade does not import the normal game modes', () {
    for (final (path, line) in _imports('lib/olympiade')) {
      for (final mode in _normalModes) {
        expect(line.contains("package:game_counter/$mode/"), isFalse, reason: '$path: $line');
      }
    }
  });

  test('the normal game modes do not import the olympiade', () {
    for (final mode in _normalModes) {
      for (final (path, line) in _imports('lib/$mode')) {
        expect(line.contains('olympiade'), isFalse, reason: '$path: $line');
      }
    }
  });

  test('the olympiade core does not import a specific edition', () {
    for (final (path, line) in _imports('lib/olympiade/core')) {
      expect(line.contains('ausgabe_'), isFalse, reason: '$path: $line');
    }
  });
}
