import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/nestap_logo.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../home/home_providers.dart';
import '../../../settings/presentation/providers/theme_mode_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final home = ref.watch(currentHomeProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final demo = ref.watch(appConfigProvider).useDemoBackend;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: EdgeInsets.all(context.pagePadding),
        children: [
          ResponsiveCenter(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.cyan400,
                          foregroundColor: AppColors.navy,
                          child: Text(
                            user?.initials ?? '?',
                            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? '',
                                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(user?.contact ?? '', style: text.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.home_outlined),
                        title: const Text('Home management'),
                        subtitle: Text(home == null ? 'Rooms and members' : '${home.name} · rooms and members'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(Routes.homeManagement),
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Appearance', style: text.titleMedium),
                            const SizedBox(height: AppSpacing.md),
                            SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.brightness_auto_rounded),
                                  label: Text('System'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode_rounded),
                                  label: Text('Light'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_rounded),
                                  label: Text('Dark'),
                                ),
                              ],
                              selected: {themeMode},
                              onSelectionChanged: (s) =>
                                  ref.read(themeModeProvider.notifier).set(s.first),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      const ListTile(
                        leading: Icon(Icons.notifications_none_rounded),
                        title: Text('Notifications'),
                        trailing: Icon(Icons.chevron_right_rounded),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text('About Nestap'),
                        subtitle: Text(demo ? 'Version 0.1.0 · demo mode' : 'Version 0.1.0'),
                        onTap: () => showAboutDialog(
                          context: context,
                          applicationName: 'Nestap',
                          applicationVersion: '0.1.0',
                          applicationIcon: const NestapLogo(height: 24),
                          applicationLegalese: '© 2026 NesTap',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context, ref),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in any time with your email or phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } on Object catch (e) {
      if (context.mounted) context.showError(e);
    }
  }
}
