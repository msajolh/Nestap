import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/repositories/device_repository_impl.dart';
import 'domain/repositories/device_repository.dart';
import 'domain/usecases/device_usecases.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => DeviceRepositoryImpl(ref.watch(apiClientProvider)),
);

final getHomeDevicesProvider = Provider(
  (ref) => GetHomeDevices(ref.watch(deviceRepositoryProvider)),
);

final sendDeviceCommandProvider = Provider(
  (ref) => SendDeviceCommand(ref.watch(deviceRepositoryProvider)),
);
