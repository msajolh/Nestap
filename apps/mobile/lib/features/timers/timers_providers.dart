import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/timer_repository_impl.dart';
import 'domain/entities/device_timer.dart';
import 'domain/repositories/timer_repository.dart';

final timerRepositoryProvider = Provider<TimerRepository>(
  (ref) => TimerRepositoryImpl(ref.watch(apiClientProvider)),
);

/// Schedules of one device. Mutations go through the repository, then
/// `ref.invalidate(deviceTimersProvider(id))`.
final deviceTimersProvider = FutureProvider.family<List<DeviceTimer>, String>(
  (ref, deviceId) => ref.watch(timerRepositoryProvider).getTimers(deviceId),
);
