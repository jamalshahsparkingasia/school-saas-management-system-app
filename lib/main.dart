import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/session.dart';

/// App entry point.
///
/// The whole app is wrapped in a [ChangeNotifierProvider] so any widget,
/// anywhere, can reach the shared [Session] (who is logged in, the API
/// client, the school's branding) with `context.watch<Session>()`.
void main() {
  final session = Session();
  session.restore(); // check for a saved login before first frame settles

  runApp(
    ChangeNotifierProvider.value(
      value: session,
      child: const PrimeSchoolApp(),
    ),
  );
}

class PrimeSchoolApp extends StatelessWidget {
  const PrimeSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    // `watch` = rebuild this widget whenever Session calls notifyListeners.
    final session = context.watch<Session>();

    return MaterialApp(
      title: 'PrimeSchoolOS',
      debugShowCheckedModeBanner: false,
      theme: _theme(session),
      // No named routes needed: the visible screen simply follows the
      // session state. Log in → dashboard appears. Log out → login appears.
      home: session.restoring
          ? const _SplashScreen()
          : session.isLoggedIn
              ? const HomeShell()
              : const LoginScreen(),
    );
  }

  /// Build the Material theme, seeded with the school's brand colour so
  /// every family's app matches their school. Before login (or if the
  /// school has no colour set) we fall back to PrimeSchoolOS evergreen.
  ThemeData _theme(Session session) {
    final seed = _parseHex(session.schoolColorHex) ?? const Color(0xFF1C7A5A);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// '#1c7a5a' → Color. Returns null for missing/malformed values.
  Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}

/// Shown for the split second while the saved session is being restored.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
