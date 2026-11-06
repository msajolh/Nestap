import 'dart:math';

import 'package:dio/dio.dart';

import '../error/failures.dart';

typedef JsonMap = Map<String, dynamic>;

/// Thin wrapper over Dio used by every remote data source.
///
/// - Maps transport errors to [Failure]s (see `docs/architecture/04-backend-services.md` §2.1).
/// - Adds an `Idempotency-Key` to commands and creates, so retries are safe.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<JsonMap> get(String path, {Map<String, Object?>? query}) =>
      _guard(() => _dio.get<Object?>(path, queryParameters: query));

  Future<JsonMap> post(String path, {Object? body, bool idempotent = false}) =>
      _guard(
        () => _dio.post<Object?>(
          path,
          data: body,
          options: idempotent
              ? Options(headers: {'Idempotency-Key': newIdempotencyKey()})
              : null,
        ),
      );

  Future<JsonMap> put(String path, {Object? body}) =>
      _guard(() => _dio.put<Object?>(path, data: body));

  Future<JsonMap> delete(String path) =>
      _guard(() => _dio.delete<Object?>(path));

  /// Reads `{"items": [...]}` list responses.
  static List<JsonMap> items(JsonMap json) =>
      (json['items'] as List<Object?>? ?? const []).cast<JsonMap>();

  static Future<JsonMap> _guard(
    Future<Response<Object?>> Function() call,
  ) async {
    try {
      final response = await call();
      final data = response.data;
      return data is JsonMap ? data : <String, dynamic>{};
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

Failure mapDioException(DioException e) {
  if (e.error is Failure) return e.error! as Failure;

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      break;
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return const UnknownFailure();
  }

  final status = e.response?.statusCode ?? 0;
  final body = e.response?.data;
  final error = body is Map ? body['error'] : null;
  final code = error is Map ? error['code'] as String? : null;
  final message = error is Map ? error['message'] as String? : null;

  return switch ((status, code)) {
    (401, _) => const UnauthorizedFailure(),
    (_, 'DEVICE_OFFLINE') => const DeviceOfflineFailure(),
    (422, _) || (_, 'VALIDATION_FAILED') =>
      ValidationFailure(message ?? 'Please check what you entered.'),
    _ => ServerFailure(message ?? 'Server error ($status).', code: code),
  };
}

String newIdempotencyKey() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
