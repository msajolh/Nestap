/// Build-time configuration, supplied with `--dart-define`.
///
/// ```bash
/// flutter run \
///   --dart-define=NESTAP_API_URL=https://api.ap-southeast.nestap.io \
///   --dart-define=NESTAP_RT_URL=wss://rt.ap-southeast.nestap.io/v1/stream
/// ```
///
/// With no `NESTAP_API_URL` the app runs against the in-memory demo backend
/// (`lib/core/dev/`), so the UI can be developed before the cloud exists.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.realtimeUrl,
    required this.region,
  });

  const AppConfig.fromEnvironment()
      : apiBaseUrl = const String.fromEnvironment('NESTAP_API_URL'),
        realtimeUrl = const String.fromEnvironment('NESTAP_RT_URL'),
        region = const String.fromEnvironment(
          'NESTAP_REGION',
          defaultValue: 'ap-southeast',
        );

  final String apiBaseUrl;
  final String realtimeUrl;
  final String region;

  bool get useDemoBackend => apiBaseUrl.isEmpty;
}
