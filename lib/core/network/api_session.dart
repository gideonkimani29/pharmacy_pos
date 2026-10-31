import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

abstract interface class TokenStorage {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> writeTokens({required String accessToken, required String refreshToken});
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'pharmacy_pos.access_token';
  static const _refreshKey = 'pharmacy_pos.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> writeTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

class ApiSession extends ChangeNotifier {
  ApiSession({
    required String baseUrl,
    TokenStorage? tokenStorage,
    http.Client? client,
  })  : _baseUri = _parseBaseUrl(baseUrl),
        _tokenStorage = tokenStorage ?? SecureTokenStorage(),
        _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 15);

  final Uri _baseUri;
  final TokenStorage _tokenStorage;
  final http.Client _client;

  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshFlight;
  bool _initialized = false;
  ApiException? _restoreError;
  bool _disposed = false;

  bool get isInitialized => _initialized;
  bool get isAuthenticated => _accessToken != null;
  ApiException? get restoreError => _restoreError;

  static Uri _parseBaseUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError.value(value, 'baseUrl', 'Must be an absolute HTTP(S) URL.');
    }
    return Uri.parse(trimmed.endsWith('/') ? trimmed : '$trimmed/');
  }

  Future<void> restore() async {
    _initialized = false;
    _restoreError = null;
    _notify();
    try {
      _refreshToken = await _tokenStorage.readRefreshToken();
      _accessToken = await _tokenStorage.readAccessToken();
      if (_refreshToken != null && _refreshToken!.isNotEmpty) {
        await _refreshSession();
      } else {
        await _clearTokens();
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearTokens();
      } else {
        _restoreError = error;
      }
    } on http.ClientException {
      _restoreError = const ApiException(
        statusCode: 0,
        code: 'network_error',
        message: 'Cannot reach the Go API. Check the connection and try again.',
      );
    } on TimeoutException {
      _restoreError = const ApiException(
        statusCode: 0,
        code: 'network_timeout',
        message: 'The Go API did not respond in time. Try again.',
      );
    }
    _initialized = true;
    _notify();
  }

  Future<void> login({required String email, required String password}) async {
    final data = await _send(
      'POST',
      'auth/login',
      body: {'email': email.trim(), 'password': password},
      authenticated: false,
    );
    await _saveTokenResponse(data);
    _restoreError = null;
    _initialized = true;
    _notify();
  }

  Future<void> logout() async {
    final refreshToken = _refreshToken;
    try {
      if (refreshToken != null) {
        await _send(
          'POST',
          'auth/logout',
          body: {'refreshToken': refreshToken},
          authenticated: false,
        );
      }
    } finally {
      await _clearTokens();
      _notify();
    }
  }

  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Object?> post(
    String path, {
    Object? body,
    String? idempotencyKey,
  }) =>
      _send('POST', path, body: body, idempotencyKey: idempotencyKey);

  Future<Object?> put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<Object?> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Uri _uri(String path, Map<String, String>? query) {
    final relative = path.startsWith('/') ? path.substring(1) : path;
    final uri = _baseUri.resolve(relative);
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? idempotencyKey,
    bool authenticated = true,
    bool allowRefresh = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;

    final request = http.Request(method, _uri(path, query))..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final response = await _client.send(request).then(http.Response.fromStream).timeout(_timeout);
    if (response.statusCode == 401 && authenticated && allowRefresh) {
      if (await _refreshSession()) {
        return _send(
          method,
          path,
          body: body,
          query: query,
          idempotencyKey: idempotencyKey,
          authenticated: authenticated,
          allowRefresh: false,
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response);
    }
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<bool> _refreshSession() {
    final pending = _refreshFlight;
    if (pending != null) return pending;
    final refresh = _performRefresh();
    _refreshFlight = refresh;
    return refresh.whenComplete(() {
      _refreshFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearTokens();
      return false;
    }
    try {
      final data = await _send(
        'POST',
        'auth/refresh',
        body: {'refreshToken': refreshToken},
        authenticated: false,
      );
      await _saveTokenResponse(data);
      _notify();
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearTokens();
        _notify();
        return false;
      }
      rethrow;
    }
  }

  Future<void> _saveTokenResponse(Object? value) async {
    final data = _object(value);
    final access = data['accessToken'];
    final refresh = data['refreshToken'];
    if (access is! String || access.isEmpty || refresh is! String || refresh.isEmpty) {
      throw const FormatException('The API returned an invalid token response.');
    }
    await _tokenStorage.writeTokens(accessToken: access, refreshToken: refresh);
    _accessToken = access;
    _refreshToken = refresh;
  }

  Future<void> _clearTokens() async {
    await _tokenStorage.clear();
    _accessToken = null;
    _refreshToken = null;
  }

  ApiException _apiException(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final code = error['code'];
          final message = error['message'];
          return ApiException(
            statusCode: response.statusCode,
            code: code is String ? code : 'http_error',
            message: message is String ? message : 'The API request failed.',
          );
        }
      }
    } on FormatException {
      return ApiException(
        statusCode: response.statusCode,
        code: 'invalid_error_response',
        message: 'The API returned an invalid error response.',
      );
    }
    return ApiException(
      statusCode: response.statusCode,
      code: 'http_error',
      message: 'The API request failed (${response.statusCode}).',
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}

Map<String, dynamic> apiObject(Object? value) => _object(value);

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('The API returned an invalid object.');
}

List<Object?> apiList(Object? value) {
  if (value is List<Object?>) return value;
  throw const FormatException('The API returned an invalid list.');
}
