import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around the Laravel /api/v1 backend.
///
/// The base URL is supplied at build time via:
///   flutter build apk --dart-define=API_BASE_URL=http://192.168.1.42:8000
///
/// Defaults to the Android-emulator-friendly loopback (10.0.2.2) so
/// debug builds on the emulator just work without extra config.
class ApiService {
  static const String _defaultBaseUrl = 'http://10.0.2.2:8000';

  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  /// Root of the API, e.g. http://10.0.2.2:8000/api/v1
  static String get baseUrl => '$_envBaseUrl/api/v1';

  /// Public asset root, used to resolve drink icon_path / tip cover URLs.
  static String get assetBaseUrl => '$_envBaseUrl/storage';

  /// The web site itself, without `/api/v1`. The legal pages the stores
  /// require the paywall to link to (`/privacy`, `/terms`) are ordinary web
  /// routes on the same host, so they follow whatever `API_BASE_URL` the
  /// build was given rather than being hardcoded to a domain that does not
  /// exist yet.
  static String get siteUrl => _envBaseUrl;

  /// Ceiling on any single request. Without it a half-open connection —
  /// captive portal, backend wedged, phone on a dead cell — leaves the
  /// caller's spinner up forever with nothing to cancel it.
  static const Duration _timeout = Duration(seconds: 20);

  /// Language sent as `Accept-Language`, kept in sync with the app locale
  /// by the root widget. The backend localizes its own error messages
  /// ("The password is incorrect.", validation text) off this, which is
  /// the only signal it has before the bearer token is authenticated.
  static String languageCode = 'en';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': languageCode,
    };
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Runs [request] and turns a *transport* failure — DNS, refused
  /// connection, TLS handshake, timeout — into the same envelope shape a
  /// non-2xx response produces, with `status: 0` to mark "never reached the
  /// server". Callers already branch on `success`, so they surface a message
  /// instead of throwing out of whatever `await` they were sitting on.
  ///
  /// This matters beyond tidiness: every provider sets a `_loading` flag
  /// before the call and clears it after. An exception thrown in between
  /// skips the clear, and the button stays spinning with no error and no way
  /// back.
  static Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      return _parse(await request().timeout(_timeout));
    } on http.ClientException {
      return _offline();
    } on TimeoutException {
      return _offline();
    }
  }

  static Map<String, dynamic> _offline() => {
    'success': false,
    'status': 0,
    'data': {'message': 'No connection to the server'.tr()},
  };

  static Future<Map<String, dynamic>> get(String path) async {
    return _send(
      () async =>
          http.get(Uri.parse('$baseUrl$path'), headers: await _headers()),
    );
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _send(
      () async => http.post(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      ),
    );
  }

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _send(
      () async => http.put(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(),
        body: jsonEncode(body),
      ),
    );
  }

  /// Uploads a single file as `multipart/form-data` under [field].
  static Future<Map<String, dynamic>> upload(
    String path,
    String field,
    String filePath,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    // Content-Type is set by MultipartRequest, boundary and all.
    request.headers['Accept'] = 'application/json';
    request.headers['Accept-Language'] = languageCode;
    final token = await getToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(field, filePath));

    return _send(() async {
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
  }

  /// [body] is optional because most DELETEs identify the resource by URL,
  /// but account deletion re-checks the current password and has to carry
  /// it somewhere.
  static Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _send(
      () async => http.delete(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  static Map<String, dynamic> _parse(http.Response res) {
    dynamic body;
    try {
      body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    } catch (_) {
      body = {'message': res.body};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return {'success': true, 'data': body};
    } else {
      return {'success': false, 'data': body, 'status': res.statusCode};
    }
  }
}
