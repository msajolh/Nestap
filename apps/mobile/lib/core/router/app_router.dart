import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/devices/presentation/pages/device_detail_page.dart';
import '../../features/devices/presentation/pages/device_settings_page.dart';
import '../../features/energy/presentation/pages/energy_page.dart';
import '../../features/home/presentation/pages/home_dashboard_page.dart';
import '../../features/home/presentation/pages/home_management_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/onboarding/onboarding_providers.dart';
import '../../features/onboarding/presentation/pages/welcome_page.dart';
import '../../features/pairing/presentation/pages/add_device_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/scenes/domain/entities/rule.dart';
import '../../features/scenes/presentation/pages/rule_editor_page.dart';
import '../../features/scenes/presentation/pages/scenes_page.dart';
import '../../features/timers/presentation/pages/device_timers_page.dart';
import '../widgets/app_shell.dart';
import '../widgets/async_value_view.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // GoRouter re-runs `redirect` whenever this notifier changes.
  final auth = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref
    ..listen<AuthState>(authControllerProvider, (_, next) => auth.value = next)
    ..onDispose(auth.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onSplash = location == Routes.splash;
      final onSignIn = location == Routes.signIn;
      final onWelcome = location == Routes.welcome;
      return switch (auth.value) {
        AuthUnknown() => onSplash ? null : Routes.splash,
        Unauthenticated() => onSignIn || onWelcome
            ? null
            : (ref.read(onboardingSeenProvider) ? Routes.signIn : Routes.welcome),
        Authenticated() => onSplash || onSignIn || onWelcome ? Routes.home : null,
      };
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeDashboardPage(),
                routes: [
                  GoRoute(
                    path: 'devices/:id',
                    builder: (context, state) =>
                        DeviceDetailPage(deviceId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'settings',
                        builder: (context, state) =>
                            DeviceSettingsPage(deviceId: state.pathParameters['id']!),
                      ),
                      GoRoute(
                        path: 'timers',
                        builder: (context, state) =>
                            DeviceTimersPage(deviceId: state.pathParameters['id']!),
                      ),
                      GoRoute(
                        path: 'energy',
                        builder: (context, state) =>
                            EnergyPage(deviceId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'add-device',
                    builder: (context, state) => const AddDevicePage(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.scenes,
                builder: (context, state) => const ScenesPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => RuleEditorPage(
                      kind: state.uri.queryParameters['kind'] == 'automation'
                          ? RuleKind.automation
                          : RuleKind.scene,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'home',
                    builder: (context, state) => const HomeManagementPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: MessageView(
        icon: Icons.explore_off_rounded,
        title: 'Page not found',
        actionLabel: 'Go home',
        onAction: () => context.go(Routes.home),
      ),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
});
