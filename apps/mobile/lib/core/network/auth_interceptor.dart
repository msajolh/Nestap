import 'package:dio/dio.dart';

import '../storage/token_store.dart';

/// Adds the bearer token, refreshes it when it is about to expire, and retries
/// a request once after a 401.
///
/// A [QueuedInterceptor] handles one request at a time, so ten parallel calls
/// with an expired token cause one refresh, not ten.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this._tokenStore, required this._refreshDio});

  /// Put `extra: {AuthInterceptor.skipAuth: true}` on sign-in requests.
  static const skipAuth = 'skipAuth';
  static const _retried = 'authRetried';

  final TokenStore _tokenStore;
  final Dio _refreshDio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuth] == true) {
      handler.next(options);
      return;
    }
    var tokens = await _tokenStore.read();
    if (tokens != null && tokens.isExpired) tokens = await _refresh(tokens);
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final canRetry = err.response?.statusCode == 401 &&
        request.extra[_retried] != true &&
        request.extra[skipAuth] != true;
    if (!canRetry) {
      handler.next(err);
      return;
    }

    final current = await _tokenStore.read();
    final fresh = current == null ? null : await _refresh(current);
    if (fresh == null) {
      handler.next(err);
      return;
    }

    request
      ..headers['Authorization'] = 'Bearer ${fresh.accessToken}'
      ..extra[_retried] = true;
    try {
      handler.resolve(await _refreshDio.fetch<Object?>(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<AuthTokens?> _refresh(AuthTokens current) async {
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/v1/auth/token',
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': current.refreshToken,
        },
      );
      final fresh = AuthTokens.fromJson(response.data!);
      await _tokenStore.save(fresh);
      return fresh;
    } on DioException catch (e) {
      // Only a rejected refresh token ends the session; a network blip doesn't.
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) await _tokenStore.clear(expired: true);
      return null;
    }
  }
}
