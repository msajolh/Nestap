import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/storage/token_store.dart';
import '../models/user_dto.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._api, this._dio);

  final ApiClient _api;

  /// Raw Dio for the unauthenticated sign-in calls (they skip the auth interceptor).
  final Dio _dio;

  Future<void> requestOtp(String target) => _unauthenticated(
        '/v1/auth/otp',
        {'channel': target.contains('@') ? 'email' : 'sms', 'target': target},
      );

  Future<AuthTokens> exchangeOtp(String target, String code) async {
    final json = await _unauthenticated(
      '/v1/auth/token',
      {'grant_type': 'otp', 'target': target, 'code': code},
    );
    return AuthTokens.fromJson(json);
  }

  Future<UserDto> me() async => UserDto(await _api.get('/v1/users/me'));

  Future<void> logout() => _api.post('/v1/auth/logout');

  Future<JsonMap> _unauthenticated(String path, Map<String, Object?> body) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: body,
        options: Options(extra: {AuthInterceptor.skipAuth: true}),
      );
      final data = response.data;
      return data is JsonMap ? data : <String, dynamic>{};
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
