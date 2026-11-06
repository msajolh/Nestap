import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'dev/demo_api_interceptor.dart';
import 'dev/demo_backend.dart';
import 'dev/demo_realtime_client.dart';
import 'network/api_client.dart';
import 'network/auth_interceptor.dart';
import 'realtime/realtime_client.dart';
import 'storage/token_store.dart';

/// App-wide infrastructure providers. Feature providers build on these.

final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig.fromEnvironment(),
);

/// Overridden in `bootstrap.dart` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(secureStorageProvider)),
);

final demoBackendProvider = Provider<DemoBackend>((ref) => DemoBackend());

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final demo = config.useDemoBackend ? ref.watch(demoBackendProvider) : null;

  BaseOptions options() => BaseOptions(
        baseUrl: demo != null ? 'https://demo.nestap.invalid' : config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      );

  // Separate client for token refresh and retries, so it never re-enters
  // the auth interceptor's queue.
  final refreshDio = Dio(options());
  final dio = Dio(options());

  dio.interceptors.add(
    AuthInterceptor(tokenStore: ref.watch(tokenStoreProvider), refreshDio: refreshDio),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(requestBody: true, logPrint: (line) => debugPrint('$line')),
    );
  }
  if (demo != null) {
    // Must be last: it answers the request after auth headers are added.
    dio.interceptors.add(DemoApiInterceptor(demo));
    refreshDio.interceptors.add(DemoApiInterceptor(demo));
  }

  ref.onDispose(() {
    dio.close();
    refreshDio.close();
  });
  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final RealtimeClient client = config.useDemoBackend
      ? DemoRealtimeClient(ref.watch(demoBackendProvider))
      : WebSocketRealtimeClient(
          url: Uri.parse(config.realtimeUrl),
          tokenStore: ref.watch(tokenStoreProvider),
        );
  ref.onDispose(client.dispose);
  return client;
});
