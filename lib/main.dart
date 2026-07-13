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

  /// The app's design system, seeded with the school's brand colour so
  /// every family's app matches their school. Before login (or if the
  /// school has no colour set) we fall back to PrimeSchoolOS evergreen.
  ///
  /// Everything visual — type scale, cards, buttons, nav bar — is themed
  /// HERE once, so the screens stay clean and consistent.
  ThemeData _theme(Session session) {
    final seed = _parseHex(session.schoolColorHex) ?? const Color(0xFF1C7A5A);

    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      // A near-white, slightly cool canvas makes the white cards float.
      surface: const Color(0xFFF4F6F9),
    );

    // Manrope: a modern geometric sans that reads "product", not
    // "default". Bundled in assets/fonts (declared in pubspec.yaml) so
    // it renders instantly, even offline.
    final textTheme = Typography.blackMountainView
        .apply(fontFamily: 'Manrope')
        .apply(
          bodyColor: const Color(0xFF1A2330),
          displayColor: const Color(0xFF1A2330),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Manrope',
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A2330)),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: const Color(0xFF6B7686),
          height: 1.4,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: .2,
          ),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          textStyle:
              textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        backgroundColor: Colors.white,
        selectedColor: scheme.primaryContainer,
        labelStyle:
            textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primary.withValues(alpha: .14),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : const Color(0xFF8A94A6),
          ),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelStyle:
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle:
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.label,
      ),

      dividerTheme: DividerThemeData(color: Colors.grey.shade200),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
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
