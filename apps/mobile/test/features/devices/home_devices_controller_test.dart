import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestap/core/error/failures.dart';
import 'package:nestap/core/providers.dart';
import 'package:nestap/core/realtime/realtime_client.dart';
import 'package:nestap/core/realtime/realtime_event.dart';
import 'package:nestap/features/devices/devices_providers.dart';
import 'package:nestap/features/devices/domain/entities/device.dart';
import 'package:nestap/features/devices/domain/repositories/device_repository.dart';
import 'package:nestap/features/devices/presentation/providers/home_devices_controller.dart';
import 'package:nestap/features/home/domain/entities/home.dart';
import 'package:nestap/features/home/home_providers.dart';

class _FakeRealtime implements RealtimeClient {
  final controller = StreamController<RealtimeEvent>.broadcast();
  final subscribed = <String>{};

  @override
  Stream<RealtimeEvent> get events => controller.stream;

  @override
  void subscribeHome(String homeId) => subscribed.add(homeId);

  @override
  void unsubscribeHome(String homeId) => subscribed.remove(homeId);

  @override
  Future<void> dispose() => controller.close();
}

class _FakeDevices implements DeviceRepository {
  bool failNextCommand = false;
  final sent = <Map<String, Object?>>[];

  @override
  Future<List<Device>> getHomeDevices(String homeId) async => [
        Device(
          id: 'd1',
          homeId: homeId,
          name: 'Hall switch',
          category: DeviceCategory.switchPanel,
          productId: 'p',
          online: true,
          state: const {'switch_1': false},
          version: 3,
        ),
      ];

  @override
  Future<void> sendCommand(String deviceId, Map<String, Object?> dps) async {
    if (failNextCommand) throw const DeviceOfflineFailure();
    sent.add(dps);
  }

  @override
  Future<void> rename(String deviceId, String name) async {}

  @override
  Future<void> moveToRoom(String deviceId, String? roomId) async {}

  @override
  Future<void> remove(String deviceId) async {}
}

void main() {
  late _FakeRealtime realtime;
  late _FakeDevices repository;
  late ProviderContainer container;

  setUp(() {
    realtime = _FakeRealtime();
    repository = _FakeDevices();
    container = ProviderContainer(
      overrides: [
        currentHomeProvider.overrideWith(
          (ref) async => const Home(id: 'h1', name: 'Home', timezone: 'UTC'),
        ),
        realtimeClientProvider.overrideWithValue(realtime),
        deviceRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(homeDevicesProvider, (_, _) {});
  });

  Device hallSwitch() => container.read(homeDevicesProvider).value!.single;

  test('loads devices and subscribes to the home', () async {
    await container.read(homeDevicesProvider.future);
    expect(hallSwitch().name, 'Hall switch');
    expect(realtime.subscribed, {'h1'});
  });

  test('applies newer realtime state and ignores stale versions', () async {
    await container.read(homeDevicesProvider.future);

    realtime.controller.add(
      const DeviceStateEvent(deviceId: 'd1', version: 2, changed: {'switch_1': true}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(hallSwitch().state['switch_1'], isFalse, reason: 'version 2 < 3');

    realtime.controller.add(
      const DeviceStateEvent(deviceId: 'd1', version: 4, changed: {'switch_1': true}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(hallSwitch().state['switch_1'], isTrue);
    expect(hallSwitch().version, 4);
  });

  test('command updates optimistically', () async {
    await container.read(homeDevicesProvider.future);
    await container.read(homeDevicesProvider.notifier).setDps('d1', {'switch_1': true});
    expect(hallSwitch().state['switch_1'], isTrue);
    expect(repository.sent, [
      {'switch_1': true},
    ]);
  });

  test('failed command rolls back and rethrows', () async {
    await container.read(homeDevicesProvider.future);
    repository.failNextCommand = true;
    await expectLater(
      container.read(homeDevicesProvider.notifier).setDps('d1', {'switch_1': true}),
      throwsA(isA<DeviceOfflineFailure>()),
    );
    expect(hallSwitch().state['switch_1'], isFalse);
  });
}
