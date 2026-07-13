import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../api/api_client.dart';

/// The app's single source of truth for "who is logged in".
///
/// It extends [ChangeNotifier] — Flutter's simplest observable. Widgets
/// that `watch` this object rebuild automatically whenever we call
/// [notifyListeners], which is how the app flips between the login
/// screen and the dashboard without any manual navigation code.
///
/// It also persists the token + profile in [SharedPreferences] so the
/// user stays signed in after closing the app.
class Session extends ChangeNotifier {
  /// Where the Laravel backend lives. On the iOS simulator / desktop /
  /// web this can be a local address; on a REAL phone it must be a URL
  /// the phone can reach (your computer's LAN IP or a deployed server).
  static const defaultBaseUrl = 'http://schoolsaas.test:8020';

  ApiClient api = ApiClient(baseUrl: defaultBaseUrl);

  Map<String, dynamic>? user; // the `user` blob returned by /login
  bool restoring = true; // true while we check for a saved session

  bool get isLoggedIn => api.token != null && user != null;

  String get role => (user?['role'] as String?) ?? '';
  String get userName => (user?['name'] as String?) ?? '';

  Map<String, dynamic> get school =>
      (user?['school'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get person =>
      (user?['person'] as Map<String, dynamic>?) ?? {};

  String get schoolName => (school['name'] as String?) ?? 'PrimeSchoolOS';
  String get currency => (school['currency_symbol'] as String?) ?? '';

  /// The school's brand colour — used to theme the whole app.
  String? get schoolColorHex => school['primary_color'] as String?;

  /// Called once at startup: restore a saved session if there is one.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final savedUser = prefs.getString('user');
    final baseUrl = prefs.getString('base_url') ?? defaultBaseUrl;

    api = ApiClient(baseUrl: baseUrl, token: token);
    if (token != null && savedUser != null) {
      user = jsonDecode(savedUser) as Map<String, dynamic>;
    }

    restoring = false;
    notifyListeners();
  }

  /// Sign in against POST /api/v1/login and remember the result.
  Future<void> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    api = ApiClient(baseUrl: baseUrl);

    final data = await api.post('/login', {
      'email': email,
      'password': password,
      'device_name': 'PrimeSchoolOS app',
    });

    api.token = data['token'] as String;
    user = data['user'] as Map<String, dynamic>;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', api.token!);
    await prefs.setString('user', jsonEncode(user));
    await prefs.setString('base_url', baseUrl);

    notifyListeners();
  }

  /// Sign out: tell the server to revoke the token, then forget
  /// everything locally (even if the server call fails — the user
  /// asked to leave, so we always let them leave).
  Future<void> logout() async {
    try {
      await api.post('/logout');
    } catch (_) {/* token may already be dead — that's fine */}

    api.token = null;
    user = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');

    notifyListeners();
  }

  /// Central handler for API failures: a 401 means the token died
  /// (revoked/expired) — drop straight back to the login screen.
  void handleAuthError(Object error) {
    if (error is ApiException && error.isUnauthenticated) {
      api.token = null;
      user = null;
      SharedPreferences.getInstance().then((p) {
        p.remove('token');
        p.remove('user');
      });
      notifyListeners();
    }
  }
}
