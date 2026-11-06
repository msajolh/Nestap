import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../home/home_providers.dart';
import '../providers/home_devices_controller.dart';
import '../widgets/device_controls.dart';
import '../widgets/device_visuals.dart';

class DeviceDetailPage extends ConsumerWidget {
  const DeviceDetailPage({required this.deviceId, super.key});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceByIdProvider(deviceId));
    final rooms = ref.watch(roomsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(device.value?.name ?? 'Device'),
        actions: [
          IconButton(
            tooltip: 'Schedules',
            icon: const Icon(Icons.schedule_rounded),
            onPressed: () => context.push(Routes.deviceTimers(deviceId)),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.deviceSettings(deviceId)),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: AsyncValueView(
        value: device,
        onRetry: () => ref.invalidate(homeDevicesProvider),
        data: (device) {
          if (device == null) {
            return const MessageView(
              icon: Icons.device_unknown_rounded,
              title: 'Device not found',
              message: 'It may have been removed from this home.',
            );
          }
          final room = rooms.where((r) => r.id == device.roomId).firstOrNull;

          Future<void> send(Map<String, Object?> dps) async {
            try {
              await ref.read(homeDevicesProvider.notifier).setDps(device.id, dps);
            } on Object catch (e) {
              if (context.mounted) context.showError(e);
            }
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(context.pagePadding),
            child: ResponsiveCenter(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    [if (room != null) room.name, device.statusLine].join(' · '),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (!device.online) ...[
                    const _OfflineBanner(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  IgnorePointer(
                    ignoring: !device.online,
                    child: Opacity(
                      opacity: device.online ? 1 : 0.5,
                      child: DeviceControls(device: device, send: send),
                    ),
                  ),
                  if (device.hasMetering) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.bolt_rounded, color: AppColors.brand),
                        title: const Text(
                          'Energy usage',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text('By hour, day and month'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(Routes.deviceEnergy(device.id)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.cloud_off_rounded, color: scheme.onErrorContainer),
        title: Text(
          'Device is offline',
          style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Check that it has power and your Wi-Fi is working.',
          style: TextStyle(color: scheme.onErrorContainer),
        ),
      ),
    );
  }
}
