import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresAt: DateTime.now().add(
          Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 900),
        ),
      );

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  /// Refresh a little early so a request never leaves with a dying token.
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));
}

/// Keeps OAuth tokens in the platform keystore (Keychain / Android Keystore).
class TokenStore {
  TokenStore(this._storage);

  static const _kAccess = 'auth.access_token';
  static const _kRefresh = 'auth.refresh_token';
  static const _kExpiry = 'auth.expires_at';

  final FlutterSecureStorage _storage;
  final _cleared = StreamController<void>.broadcast();
  AuthTokens? _cache;

  /// Fires when the session ends without the user asking (refresh failed).
  Stream<void> get onSessionExpired => _cleared.stream;

  Future<AuthTokens?> read() async {
    if (_cache != null) return _cache;
    final values = await Future.wait([
      _storage.read(key: _kAccess),
      _storage.read(key: _kRefresh),
      _storage.read(key: _kExpiry),
    ]);
    final [access, refresh, expiry] = values;
    if (access == null || refresh == null || expiry == null) return null;
    return _cache = AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(int.parse(expiry)),
    );
  }

  Future<void> save(AuthTokens tokens) async {
    _cache = tokens;
    await Future.wait([
      _storage.write(key: _kAccess, value: tokens.accessToken),
      _storage.write(key: _kRefresh, value: tokens.refreshToken),
      _storage.write(
        key: _kExpiry,
        value: tokens.expiresAt.millisecondsSinceEpoch.toString(),
      ),
    ]);
  }

  /// [expired] is true when the server rejected the refresh token, which
  /// signs the user out everywhere in the app.
  Future<void> clear({bool expired = false}) async {
    _cache = null;
    await Future.wait([
      _storage.delete(key: _kAccess),
      _storage.delete(key: _kRefresh),
      _storage.delete(key: _kExpiry),
    ]);
    if (expired) _cleared.add(null);
  }
}
