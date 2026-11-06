import 'dart:async';

import 'package:dio/dio.dart';

import 'demo_backend.dart';

/// Answers API requests from [DemoBackend] instead of the network.
class DemoApiInterceptor extends Interceptor {
  DemoApiInterceptor(this._backend);

  final DemoBackend _backend;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    Timer(const Duration(milliseconds: 250), () {
      try {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: _route(options),
          ),
        );
      } on _DemoError catch (e) {
        final response = Response<Object?>(
          requestOptions: options,
          statusCode: e.status,
          data: {
            'error': {'code': e.code, 'message': e.message},
          },
        );
        handler.reject(
          DioException.badResponse(
            statusCode: e.status,
            requestOptions: options,
            response: response,
          ),
        );
      } on Object catch (e, stack) {
        handler.reject(DioException(requestOptions: options, error: e, stackTrace: stack));
      }
    });
  }

  Object? _route(RequestOptions o) {
    final path = o.path;
    final body = o.data is Map ? (o.data as Map).cast<String, Object?>() : const <String, Object?>{};
    final segments = Uri.parse(path).pathSegments;

    switch ((o.method, segments)) {
      case ('POST', ['v1', 'auth', 'otp']):
        return <String, Object?>{};
      case ('POST', ['v1', 'auth', 'token']):
        if (body['grant_type'] == 'otp' &&
            !RegExp(r'^\d{6}$').hasMatch('${body['code']}')) {
          throw const _DemoError(422, 'VALIDATION_FAILED', 'Enter the 6-digit code. In demo mode any 6 digits work.');
        }
        return {
          'access_token': 'demo-access',
          'refresh_token': 'demo-refresh',
          'expires_in': 3600,
        };
      case ('POST', ['v1', 'auth', 'logout']):
        return <String, Object?>{};
      case ('GET', ['v1', 'users', 'me']):
        return _backend.user;
      case ('GET', ['v1', 'homes']):
        return {'items': _backend.homes()};
      case ('GET', ['v1', 'homes', final homeId, 'rooms']):
        return {'items': _backend.rooms(homeId)};
      case ('GET', ['v1', 'homes', final homeId, 'devices']):
        return {'items': _backend.devices(homeId)};
      case ('GET', ['v1', 'homes', final homeId, 'rules']):
        return {'items': _backend.rules(homeId)};
      case ('POST', ['v1', 'devices', final deviceId, 'commands']):
        final device = _backend.device(deviceId);
        if (device == null) throw const _DemoError(404, 'NOT_FOUND', 'Device not found.');
        if (device['online'] != true) {
          throw const _DemoError(409, 'DEVICE_OFFLINE', 'The device is offline.');
        }
        _backend.applyDps(deviceId, (body['dps']! as Map).cast<String, Object?>());
        return {'command_id': 'c_${DateTime.now().microsecondsSinceEpoch}'};
      case ('POST', ['v1', 'rules', final ruleId, 'run']):
        _backend.runRule(ruleId);
        return {'run_id': 'run_${DateTime.now().microsecondsSinceEpoch}'};
      case ('PUT', ['v1', 'rules', final ruleId, 'enabled']):
        _backend.setRuleEnabled(ruleId, body['enabled'] == true);
        return <String, Object?>{};
      case ('POST', ['v1', 'connectors', 'tuya', 'session']):
        return {
          'tuya_uid': 'demo-uid',
          'secret': 'demo-secret',
          'tuya_home_id': 'demo-tuya-home',
          'region': 'demo',
        };
      case ('POST', ['v1', 'devices', 'import']):
        return _backend.importDevice(
          homeId: body['home_id']! as String,
          roomId: body['room_id'] as String?,
        );
    }
    throw _DemoError(404, 'NOT_FOUND', 'Demo backend has no route for ${o.method} $path');
  }
}

class _DemoError implements Exception {
  const _DemoError(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;
}
