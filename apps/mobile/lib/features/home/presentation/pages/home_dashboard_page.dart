import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../devices/domain/entities/device.dart';
import '../../../devices/presentation/providers/home_devices_controller.dart';
import '../../../devices/presentation/widgets/device_tile.dart';
import '../../domain/entities/home.dart';
import '../../home_providers.dart';
import '../widgets/home_summary_card.dart';
import '../widgets/room_filter_bar.dart';

class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(currentHomeProvider);
    return Scaffold(
      body: AsyncValueView(
        value: home,
        onRetry: () => ref.invalidate(homesProvider),
        data: (home) => home == null
            ? MessageView(
                icon: Icons.home_work_outlined,
                title: 'No home yet',
                message: 'Create a home to start adding devices.',
                actionLabel: 'Try again',
                onAction: () => ref.invalidate(homesProvider),
              )
            : _Dashboard(home: home),
      ),
      floatingActionButton: context.isCompact
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.addDevice),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add device'),
            )
          : null,
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.home});

  final Home home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDevices = ref.watch(homeDevicesProvider);
    final visible = ref.watch(visibleDevicesProvider);
    final rooms = ref.watch(roomsProvider).value ?? const <Room>[];
    final roomNames = {for (final r in rooms) r.id: r.name};

    return LayoutBuilder(
      builder: (context, constraints) {
        // Side padding grows on wide screens so content stays readable.
        final side = max(
          context.pagePadding,
          (constraints.maxWidth - Breakpoints.maxContentWidth) / 2,
        );
        final horizontal = EdgeInsets.symmetric(horizontal: side);

        return RefreshIndicator(
          onRefresh: () => ref.read(homeDevicesProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                titleSpacing: side,
                title: _HomeTitle(home: home),
                actions: [
                  if (!context.isCompact)
                    Padding(
                      padding: EdgeInsets.only(right: side),
                      child: FilledButton.icon(
                        onPressed: () => context.push(Routes.addDevice),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add device'),
                      ),
                    ),
                ],
              ),
              SliverPadding(
                padding: horizontal,
                sliver: SliverToBoxAdapter(
                  child: HomeSummaryCard(devices: allDevices.value ?? const []),
                ),
              ),
              SliverToBoxAdapter(
                child: RoomFilterBar(rooms: rooms, padding: horizontal),
              ),
              ...visible.when<List<Widget>>(
                data: (devices) => [
                  if (devices.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: MessageView(
                        icon: Icons.devices_other_rounded,
                        title: 'No devices here',
                        message: 'Add a Nestap switch, socket or curtain to control it from anywhere.',
                        actionLabel: 'Add device',
                        onAction: () => context.push(Routes.addDevice),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: horizontal,
                      sliver: _DeviceGrid(devices: devices, roomNames: roomNames),
                    ),
                ],
                loading: () => [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (error, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: MessageView(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load devices',
                      message: messageFor(error),
                      actionLabel: 'Try again',
                      onAction: () => ref.invalidate(homeDevicesProvider),
                    ),
                  ),
                ],
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        );
      },
    );
  }
}

class _HomeTitle extends ConsumerWidget {
  const _HomeTitle({required this.home});

  final Home home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homes = ref.watch(homesProvider).value ?? const <Home>[];
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(home.name, overflow: TextOverflow.ellipsis)),
        if (homes.length > 1) const Icon(Icons.expand_more_rounded),
      ],
    );
    if (homes.length < 2) return title;

    return PopupMenuButton<String>(
      tooltip: 'Switch home',
      onSelected: ref.read(selectedHomeIdProvider.notifier).select,
      itemBuilder: (context) => [
        for (final h in homes)
          CheckedPopupMenuItem(value: h.id, checked: h.id == home.id, child: Text(h.name)),
      ],
      child: title,
    );
  }
}

class _DeviceGrid extends ConsumerWidget {
  const _DeviceGrid({required this.devices, required this.roomNames});

  final List<Device> devices;
  final Map<String, String> roomNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisExtent: 156,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
        ),
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return DeviceTile(
            device: device,
            roomName: roomNames[device.roomId],
            onTap: () => context.push(Routes.device(device.id)),
            onTogglePower: device.powerCode == null
                ? null
                : (on) async {
                    try {
                      await ref
                          .read(homeDevicesProvider.notifier)
                          .setDps(device.id, device.allChannels(on));
                    } on Object catch (e) {
                      if (context.mounted) context.showError(e);
                    }
                  },
          );
        },
      );
}
