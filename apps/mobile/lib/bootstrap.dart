import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';

/// Initialises platform services, then starts the app inside a [ProviderScope].
///
/// Everything that needs `await` before the first frame (preferences, config)
/// is resolved here and injected with provider overrides, so providers stay
/// synchronous.
Future<void> bootstrap() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // TODO(observability): forward to crash reporting (Sentry / Crashlytics).
  };
  binding.platformDispatcher.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  final prefs = await SharedPreferences.getInstance();
  const config = AppConfig.fromEnvironment();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const NestapApp(),
    ),
  );
}
