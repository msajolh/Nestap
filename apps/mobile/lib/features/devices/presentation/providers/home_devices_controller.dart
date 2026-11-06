import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../home/home_providers.dart';
import '../../devices_providers.dart';
import '../../domain/entities/device.dart';

final homeDevicesProvider =
    AsyncNotifierProvider<HomeDevicesController, List<Device>>(
  HomeDevicesController.new,
);

/// Devices of the current home, kept live by realtime events.
///
/// Commands update the UI optimistically and roll back if the cloud rejects
/// them; the device's own report (via realtime) then confirms the state.
class HomeDevicesController extends AsyncNotifier<List<Device>> {
  @override
  Future<List<Device>> build() async {
    final realtime = ref.watch(realtimeClientProvider);
    final getDevices = ref.watch(getHomeDevicesProvider);
    final home = await ref.watch(currentHomeProvider.future);
    if (home == null || !ref.mounted) return const [];

    realtime.subscribeHome(home.id);
    final subscription = realtime.events.listen(_onEvent);
    ref.onDispose(() {
      subscription.cancel();
      realtime.unsubscribeHome(home.id);
    });

    return getDevices(home.id);
  }

  Future<void> setDps(String deviceId, Map<String, Object?> dps) async {
    final before = state.value;
    final device = before?.where((d) => d.id == deviceId).firstOrNull;
    if (before == null || device == null) return;

    _replace(device.applyChanges(dps));
    try {
      await ref.read(sendDeviceCommandProvider)(device, dps);
    } on Object {
      // Roll back only the keys we changed; realtime may have moved others.
      if (ref.mounted) {
        final current = _find(deviceId);
        if (current != null) {
          _replace(
            current.applyChanges({for (final key in dps.keys) key: device.state[key]}),
          );
        }
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  void _onEvent(RealtimeEvent event) {
    switch (event) {
      case DeviceStateEvent(:final deviceId, :final version, :final changed):
        final device = _find(deviceId);
        if (device != null && version >= device.version) {
          _replace(device.applyChanges(changed, version: version));
        }
      case DevicePresenceEvent(:final deviceId, :final online):
        final device = _find(deviceId);
        if (device != null) _replace(device.copyWith(online: online));
      case DeviceAddedEvent() || DeviceRemovedEvent():
        ref.invalidateSelf();
      case UnknownRealtimeEvent():
        break;
    }
  }

  Device? _find(String id) => state.value?.where((d) => d.id == id).firstOrNull;

  void _replace(Device updated) {
    final devices = state.value;
    if (devices == null) return;
    state = AsyncData([for (final d in devices) d.id == updated.id ? updated : d]);
  }
}

/// One device, for the detail page.
final deviceByIdProvider = Provider.family<AsyncValue<Device?>, String>(
  (ref, id) => ref
      .watch(homeDevicesProvider)
      .whenData((devices) => devices.where((d) => d.id == id).firstOrNull),
);

/// Dashboard list, filtered by the selected room.
final visibleDevicesProvider = Provider<AsyncValue<List<Device>>>((ref) {
  final roomId = ref.watch(selectedRoomIdProvider);
  return ref.watch(homeDevicesProvider).whenData(
        (devices) => roomId == null
            ? devices
            : devices.where((d) => d.roomId == roomId).toList(),
      );
});
