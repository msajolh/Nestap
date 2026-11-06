import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../home/domain/entities/home.dart';
import '../../../home/home_providers.dart';
import '../../domain/entities/device.dart';
import '../providers/home_devices_controller.dart';
import '../widgets/device_visuals.dart';

class DeviceSettingsPage extends ConsumerWidget {
  const DeviceSettingsPage({required this.deviceId, super.key});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceByIdProvider(deviceId));
    final rooms = ref.watch(roomsProvider).value ?? const <Room>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Device settings')),
      body: AsyncValueView(
        value: device,
        data: (device) => device == null
            ? const MessageView(icon: Icons.device_unknown_rounded, title: 'Device not found')
            : ListView(
                padding: EdgeInsets.all(context.pagePadding),
                children: [
                  ResponsiveCenter(
                    maxWidth: 720,
                    child: _Settings(device: device, rooms: rooms),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings({required this.device, required this.rooms});

  final Device device;
  final List<Room> rooms;

  Future<void> _guard(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(homeDevicesProvider.notifier);
    final room = rooms.where((r) => r.id == device.roomId).firstOrNull;
    final text = Theme.of(context).textTheme;

    Future<void> rename() async {
      final name = await showTextInputDialog(
        context,
        title: 'Device name',
        label: 'Name',
        initial: device.name,
      );
      if (name != null && context.mounted) {
        await _guard(context, () => controller.rename(device.id, name));
      }
    }

    Future<void> pickRoom() async {
      // Wrapped so "No room" (null) is distinguishable from "dismissed".
      final picked = await showAppSheet<({String? id})>(
        context,
        title: 'Move to room',
        builder: (sheet) => ListView(
          shrinkWrap: true,
          children: [
            for (final option in [null, ...rooms])
              ListTile(
                title: Text(option?.name ?? 'No room'),
                trailing: option?.id == device.roomId
                    ? const Icon(Icons.check_rounded, color: AppColors.brand)
                    : null,
                onTap: () => Navigator.pop(sheet, (id: option?.id)),
              ),
          ],
        ),
      );
      if (picked != null && picked.id != device.roomId && context.mounted) {
        await _guard(context, () => controller.moveToRoom(device.id, picked.id));
      }
    }

    Future<void> remove() async {
      final ok = await showConfirmDialog(
        context,
        title: 'Remove ${device.name}?',
        message: 'It will be reset and can be paired again. Its schedules and history are deleted.',
        confirm: 'Remove',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
      await _guard(context, () async {
        await controller.remove(device.id);
        if (context.mounted) context.go(Routes.home);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.all(AppRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.activeGradient,
                  ),
                  child: Icon(device.icon, color: AppColors.navy, size: 28),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        room?.name ?? 'No room',
                        style: text.bodyMedium?.copyWith(color: AppColors.gray300),
                      ),
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
              _NavTile(icon: Icons.edit_outlined, title: 'Name', value: device.name, onTap: rename),
              const Divider(indent: 56),
              _NavTile(
                icon: Icons.meeting_room_outlined,
                title: 'Room',
                value: room?.name ?? 'No room',
                onTap: pickRoom,
              ),
              const Divider(indent: 56),
              _NavTile(
                icon: Icons.schedule_rounded,
                title: 'Schedules',
                onTap: () => context.push(Routes.deviceTimers(device.id)),
              ),
              if (device.hasMetering) ...[
                const Divider(indent: 56),
                _NavTile(
                  icon: Icons.bolt_rounded,
                  title: 'Energy',
                  onTap: () => context.push(Routes.deviceEnergy(device.id)),
                ),
              ],
            ],
          ),
        ),
        const SectionLabel('Device info'),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Device ID'),
                subtitle: Text(device.id),
                trailing: IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: device.id));
                    if (context.mounted) context.showMessage('Device ID copied');
                  },
                ),
              ),
              const Divider(),
              ListTile(title: const Text('Product'), subtitle: Text(device.productId)),
              const Divider(),
              ListTile(title: const Text('Connection'), subtitle: Text(_transportLabel(device.transport))),
              const Divider(),
              ListTile(title: const Text('Status'), subtitle: Text(device.online ? 'Online' : 'Offline')),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: remove,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Remove device'),
        ),
      ],
    );
  }

  static String _transportLabel(String transport) => switch (transport) {
        'tuya_cloud' => 'Tuya cloud',
        'nestap_mqtt' => 'Nestap cloud (direct)',
        'gateway_zigbee' => 'Zigbee via gateway',
        'gateway_matter' => 'Matter via gateway',
        _ => transport,
      };
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.title, required this.onTap, this.value});

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  value!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: onTap,
      );
}
