import 'dart:convert';

import 'package:http/http.dart' as http;

/// One tiny class through which EVERY network call in the app flows.
///
/// Why one class? Three things must happen on every request and it's easy
/// to forget one of them if each screen builds its own requests:
///   1. the server address (baseUrl) is prepended,
///   2. the login token is attached as an `Authorization: Bearer` header,
///   3. errors come back as a friendly [ApiException] instead of a crash.
///
/// Screens just call:  api.get('/student/dashboard')
/// and receive the decoded `data` part of the server's JSON envelope
/// ( {"success": true, "message": "...", "data": {...}} ).
class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  /// Server root, e.g. `http://schoolsaas.test:8020` — the `/api/v1`
  /// prefix is added here so screens use short paths like `/me`.
  final String baseUrl;

  /// The Sanctum bearer token received at login. Null before login.
  String? token;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api/v1$path').replace(queryParameters: query);

  /// GET a resource. Returns the `data` map from the JSON envelope.
  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    final res = await http.get(_uri(path, query), headers: _headers);
    return _decode(res);
  }

  /// GET a paginated list — returns the whole envelope because paginated
  /// responses carry `data` (the rows) and `meta` (page info) side by side.
  Future<Map<String, dynamic>> getRaw(String path,
      {Map<String, String>? query}) async {
    final res = await http.get(_uri(path, query), headers: _headers);
    return _decodeEnvelope(res);
  }

  /// POST a JSON body. Returns the `data` map from the envelope.
  Future<Map<String, dynamic>> post(String path,
      [Map<String, dynamic>? body]) async {
    final res = await http.post(_uri(path),
        headers: _headers, body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final envelope = _decodeEnvelope(res);
    final data = envelope['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// Every API response uses the same envelope. Decode it once, here:
  /// success → hand back the JSON; failure → throw an [ApiException]
  /// with the clearest message the server gave us.
  Map<String, dynamic> _decodeEnvelope(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected server response (HTTP ${res.statusCode}).');
    }

    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok && json['success'] != false) return json;

    // Laravel validation errors arrive as {"errors": {"field": ["msg"]}}.
    var message = (json['message'] as String?) ?? 'Something went wrong.';
    final errors = json['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) message = first.first.toString();
    }

    throw ApiException(message, statusCode: res.statusCode);
  }
}

/// A network/API failure with a message safe to show the user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// True when the token is missing/expired — the app reacts by
  /// sending the user back to the login screen.
  bool get isUnauthenticated => statusCode == 401;

  @override
  String toString() => message;
}
